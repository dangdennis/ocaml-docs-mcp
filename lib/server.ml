open Eio.Std
open Client

type request = {
  id : string option;
  method_name : string;
  params : Yojson.Safe.t option;
}

type route = {
  method_ : string;
  path : string;
  handler : string -> string -> int * string;
}

let parse_request json =
  try
    let open Yojson.Safe.Util in
    let id = json |> member "id" |> to_string_option in
    let method_name = json |> member "method" |> to_string in
    let params = json |> member "params" in
    Ok { id; method_name; params = Some params }
  with e -> Error (Printexc.to_string e)

let handle_get_package_info ~env ~net request =
  match request.params with
  | Some params -> (
      let open Yojson.Safe.Util in
      let package_name = params |> member "packageName" |> to_string in
      let version = params |> member "version" |> to_string in
      let pkg_req = Client.{ package_name; version } in
      match Client.fetch_package_info ~env ~net pkg_req with
      | Ok package_info -> (
          match package_info with
          | Ok package_data ->
              let result =
                Yojson.Safe.to_string
                  (Types.package_info_to_yojson package_data)
              in
              Types.{ id = request.id; result = Some result; error = None }
          | Error err ->
              let error = Types.{ message = err; code = 500 } in
              Types.{ id = request.id; result = None; error = Some error })
      | Error msg ->
          let error = Types.{ message = msg; code = 500 } in
          Types.{ id = request.id; result = None; error = Some error })
  | None ->
      let error = Types.{ message = "Missing params"; code = 400 } in
      Types.{ id = request.id; result = None; error = Some error }

let handle_get_status ~env ~net request =
  match request.params with
  | Some params -> (
      let open Yojson.Safe.Util in
      let package_name = params |> member "packageName" |> to_string in
      let version = params |> member "version" |> to_string in
      let pkg_req = { package_name; version } in
      match Client.fetch_status ~env ~net pkg_req with
      | Ok status -> (
          match status with
          | Ok status_data ->
              let result =
                Yojson.Safe.to_string (Types.status_to_yojson status_data)
              in
              Types.{ id = request.id; result = Some result; error = None }
          | Error err ->
              let error = Types.{ message = err; code = 500 } in
              Types.{ id = request.id; result = None; error = Some error })
      | Error msg ->
          let error = Types.{ message = msg; code = 500 } in
          Types.{ id = request.id; result = None; error = Some error })
  | None ->
      let error = Types.{ message = "Missing params"; code = 400 } in
      Types.{ id = request.id; result = None; error = Some error }

let handle_request ~env ~net request =
  match request.method_name with
  | "getPackageInfo" -> handle_get_package_info ~env ~net request
  | "getStatus" -> handle_get_status ~env ~net request
  | _ ->
      let error = Types.{ message = "Unknown method"; code = 404 } in
      Types.{ id = request.id; result = None; error = Some error }

let process_rpc ~env ~net body =
  match Yojson.Safe.from_string body |> parse_request with
  | Ok request ->
      let response = handle_request ~env ~net request in
      let body =
        Yojson.Safe.to_string (Types.mcp_response_to_yojson response)
      in
      (200, body)
  | Error msg ->
      let error = Types.{ message = msg; code = 400 } in
      let response = Types.{ id = None; result = None; error = Some error } in
      let body =
        Yojson.Safe.to_string (Types.mcp_response_to_yojson response)
      in
      (400, body)

let path_match pattern path =
  let pattern_parts =
    String.split_on_char '/' pattern |> List.filter (fun s -> s <> "")
  in
  let path_parts =
    String.split_on_char '/' path |> List.filter (fun s -> s <> "")
  in

  let rec match_parts patterns paths params =
    match (patterns, paths) with
    | [], [] -> Some params (* Exact match *)
    | [], _ -> None (* Pattern too short *)
    | _, [] -> None (* Path too short *)
    | p :: ps, path :: paths_rest ->
        if String.length p > 0 && p.[0] = ':' then
          (* Parameter capture *)
          let param_name = String.sub p 1 (String.length p - 1) in
          match_parts ps paths_rest ((param_name, path) :: params)
        else if p = path then
          (* Exact part match *)
          match_parts ps paths_rest params
        else
          (* Mismatch *)
          None
  in

  match_parts pattern_parts path_parts []

let route routes method_ path body =
  let matching_route =
    List.find_opt
      (fun route ->
        route.method_ = method_ && path_match route.path path <> None)
      routes
  in

  match matching_route with
  | Some route -> route.handler path body
  | None -> (404, "{\"error\": {\"message\": \"Not found\", \"code\": 404}}")

let get_path_params pattern path =
  match path_match pattern path with Some params -> params | None -> []

let status_to_code_and_text = function
  | `OK -> (200, "OK")
  | `Created -> (201, "Created")
  | `Accepted -> (202, "Accepted")
  | `No_content -> (204, "No Content")
  | `Bad_request -> (400, "Bad Request")
  | `Unauthorized -> (401, "Unauthorized")
  | `Forbidden -> (403, "Forbidden")
  | `Not_found -> (404, "Not Found")
  | `Method_not_allowed -> (405, "Method Not Allowed")
  | `Internal_server_error -> (500, "Internal Server Error")
  | `Not_implemented -> (501, "Not Implemented")
  | `Service_unavailable -> (503, "Service Unavailable")
  | `Code code -> (code, "")

let respond_string ~status ~(headers : Http.Header.t) ~body () =
  let code, text = status_to_code_and_text status in
  let status_text = if text = "" then "" else " " ^ text in
  let headers_str =
    String.concat "\r\n"
      (List.map
         (fun (k, v) -> Printf.sprintf "%s: %s" k v)
         (Http.Header.to_list headers))
  in
  Printf.sprintf "HTTP/1.1 %d%s\r\n%s\r\n\r\n%s" code status_text headers_str
    body

let start_server ~sw ~env ~net ~port routes =
  let handle_client flow addr =
    try
      let buffer = Cstruct.create 4096 in
      let len = Eio.Flow.single_read flow buffer in
      if len > 0 then
        let request_str = Cstruct.to_string buffer ~len in
        let request_line, rest =
          match String.split_on_char '\n' request_str with
          | [] -> ("", "")
          | first :: rest -> (first, String.concat "\n" rest)
        in

        let method_, path, _version =
          match String.split_on_char ' ' request_line with
          | [ m; p; v ] -> (m, p, v)
          | _ -> ("GET", "/", "HTTP/1.1")
        in

        let headers, body =
          match String.split_on_char '\r' rest with
          | [] -> ([], "")
          | parts ->
              let rec find_empty_line acc = function
                | [] -> (List.rev acc, "")
                | "\n" :: rest -> (List.rev acc, String.concat "\r" rest)
                | h :: t -> find_empty_line (h :: acc) t
              in
              find_empty_line [] parts
        in

        let status, response_body = route routes method_ path body in

        let response =
          Printf.sprintf "HTTP/1.1 %d %s\r\n%s\r\n\r\n%s" status
            (match status with
            | 200 -> "OK"
            | 404 -> "Not Found"
            | 400 -> "Bad Request"
            | 500 -> "Internal Server Error"
            | _ -> "Unknown")
            "Content-Type: application/json\r\nAccess-Control-Allow-Origin: *"
            response_body
        in

        Eio.Flow.copy_string response flow
    with exn ->
      let error_msg = Printexc.to_string exn in
      Printf.eprintf "Error handling client: %s\n%!" error_msg;
      let response =
        Printf.sprintf
          "HTTP/1.1 500 Internal Server Error\r\n\
           Content-Type: text/plain\r\n\
           Content-Length: %d\r\n\
           \r\n\
           %s"
          (String.length error_msg) error_msg
      in
      Eio.Flow.copy_string response flow
  in

  Printf.printf "Server listening on port %d\n%!" port;

  let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, port) in

  let listening_socket =
    Eio.Net.listen net ~sw ~backlog:10 ~reuse_addr:true addr
  in

  Eio.Net.run_server listening_socket handle_client
    ~on_error:(fun exn ->
      Printf.eprintf "Error handling connection: %s\n%!"
        (Printexc.to_string exn))
    ~max_connections:100
