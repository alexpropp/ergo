(*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *)

open Util
open ErgoComp

(** Ergo errors *)
exception Ergo_Error of eerror
val ergo_raise : eerror -> 'a

val error_kind : eerror -> string
val error_message : eerror -> string
val error_loc_start : eerror -> location_point
val error_loc_end : eerror -> location_point

(** [ergo_system_error msg] *)
val ergo_system_error : string -> eerror
(** [ergo_parse_error msg filename start end] *)
val ergo_parse_error : string -> string -> Lexing.position -> Lexing.position -> eerror

val wrap_jerrors : ('a -> 'b) -> 'a eresult -> 'b

val string_of_error_with_source : string -> eerror -> string
val string_of_error_with_table : (string * string) list -> eerror -> string

(** [mk_provenance_of_loc_pair filename start end] *)
val mk_provenance_of_loc_pair : string -> Lexing.position -> Lexing.position -> provenance

(** [get_version msg] *)
val ergo_version : string
val get_version : string -> (unit -> unit)

val parse_args :
  ('conf -> (Arg.key * Arg.spec * Arg.doc) list)
  -> Arg.usage_msg
  -> string array
  -> 'conf
  -> ((string * string) list * (string * string) list)

val patch_argv : string array -> string array

(** CTO *)
val cto_import_decl_of_import_namespace : string -> provenance import_decl
val unpatch_cto_extension : string -> string

(** Topological sort *)
val labels_of_graph : ('a,'b) ergo_input list -> (string * string list) list
val topo_sort_inputs : ('a,'b) ergo_input list -> ('a,'b) ergo_input list

(** Backend *)
val ergo_call : string -> string

