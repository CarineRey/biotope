open Core_kernel
open Bistro
open Bistro_engine

let np = ref 4
let mem = ref 4

let with_workflow w ~f =
  let open Scheduler in
  let db = Db.init_exn "_bistro" in
  let loggers = [ Bistro_utils.Console_logger.create () ] in
  let sched = create ~np:!np ~mem:(`GB !mem) ~loggers db in
  let thread = eval_exn sched w in
  start sched ;
  try
    Lwt_main.run thread
    |> f
  with Failure msg as e -> print_endline msg ; raise e

let eval w =
  with_workflow w ~f:Fn.id

let path w =
  with_workflow (Workflow.eval_path w) ~f:(fun x -> x)

let less w =
  Sys.command (sprintf "less %s" (path w))
  |> ignore

let firefox w =
  Sys.command (sprintf "firefox %s" (path w))
  |> ignore

let seaview w =
  Sys.command (sprintf "seaview %s" (path w))
  |> ignore

let evince w =
  Sys.command (sprintf "evince %s" (path w))
  |> ignore

let workflow_of_template t =
  let open Bistro.Shell_dsl in
  Workflow.shell [
    cmd "cp" [ file_dump t ; dest ]
  ]
