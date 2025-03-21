type status = {
  package_name : string;
  version : string;
  status : string;
  error : string option;
} [@@deriving yojson]

type module_info = {
  name : string;
  doc : string option;
  path : string;
  type_declarations : string list;
  values : string list;
  submodules : string list;
} [@@deriving yojson]

type package_info = {
  name : string;
  version : string;
  description : string option;
  modules : module_info list;
} [@@deriving yojson]

(* MCP protocol response types *)
type mcp_error = {
  message : string;
  code : int;
} [@@deriving yojson]

type mcp_response = {
  id : string option;
  result : string option;  (* JSON string *)
  error : mcp_error option;
} [@@deriving yojson] 