open Eio.Std
open Ocaml_mcp

let package_handler ~env ~net path body =
  let path_parts =
    String.split_on_char '/' path |> List.filter (fun s -> s <> "")
  in

  match path_parts with
  | [ "packages"; package_name; version; "info" ] -> (
      let pkg_req = Client.{ package_name; version } in
      match Client.fetch_package_info ~env ~net pkg_req with
      | Ok result -> (
          match result with
          | Ok info ->
              let body =
                Yojson.Safe.to_string (Types.package_info_to_yojson info)
              in
              (200, body)
          | Error err ->
              let error_body =
                Printf.sprintf {|{"error": {"message": "%s", "code": 500}}|} err
              in
              (500, error_body))
      | Error msg ->
          let error_body =
            Printf.sprintf {|{"error": {"message": "%s", "code": 500}}|} msg
          in
          (500, error_body))
  | [ "packages"; package_name; version; "status" ] -> (
      let pkg_req = Client.{ package_name; version } in
      match Client.fetch_status ~env ~net pkg_req with
      | Ok result -> (
          match result with
          | Ok status ->
              let body =
                Yojson.Safe.to_string (Types.status_to_yojson status)
              in
              (200, body)
          | Error err ->
              let error_body =
                Printf.sprintf {|{"error": {"message": "%s", "code": 500}}|} err
              in
              (500, error_body))
      | Error msg ->
          let error_body =
            Printf.sprintf {|{"error": {"message": "%s", "code": 500}}|} msg
          in
          (500, error_body))
  | _ -> (404, {|{"error": {"message": "Not found", "code": 404}}|})

let mcp_handler ~env ~net path body =
  match Server.process_rpc ~env ~net body with status, body -> (status, body)

let () =
  let port = 8080 in
  Eio_main.run @@ fun env ->
  let net = Eio.Stdenv.net env in

  let routes =
    [
      (* MCP JSON-RPC endpoint *)
      Server.
        { method_ = "POST"; path = "/mcp"; handler = mcp_handler ~env ~net };
      (* RESTful API endpoints *)
      Server.
        {
          method_ = "GET";
          path = "/packages/:package_name/:version/info";
          handler = package_handler ~env ~net;
        };
      Server.
        {
          method_ = "GET";
          path = "/packages/:package_name/:version/status";
          handler = package_handler ~env ~net;
        };
    ]
  in

  Printf.printf "Starting MCP server on http://localhost:%d\n" port;
  Printf.printf "Press Ctrl+C to stop the server\n%!";

  Switch.run @@ fun sw -> Server.start_server ~sw ~env ~net ~port routes
