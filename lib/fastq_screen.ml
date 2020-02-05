open Core_kernel
open Bistro
open Bistro.Shell_dsl

let img = [ docker_image ~account:"pveber" ~name:"fastq-screen" ~tag:"0.11.1" () ]

let rec filter_expr res = function
    [] -> string res
  | h :: t ->
    let res = match h with
      | `Not_map -> res ^ "0"
      | `Uniquely -> res ^ "1"
      | `Multi_maps -> res ^ "2"
      | `Maps -> res ^ "3"
      | `Not_map_or_Uniquely -> res ^ "4"
      | `Not_map_or_Multi_maps -> res ^ "5"
      | `Ignore -> res ^ "-"
    in
    filter_expr res t

let top_expr = function
  | `top1 x -> string (Int.to_string x)
  | `top2 (x, y) -> string (Int.to_string x ^ "," ^ Int.to_string y)

let configuration genomes =
  let database_lines = List.map genomes ~f:(fun (name, fa) ->
      let index = Bowtie2.bowtie2_build fa in
      seq ~sep:"\t" [
        string "DATABASE" ;
        string name ;
        dep index // "index"
      ]
    )
  in
  seq ~sep:"\n" database_lines

let fastq_screen ?bowtie2_opts ?filter ?illumina ?nohits ?pass ?subset
    ?tag ?(threads = 1) ?top ?(lightweight = true) fqs genomes =
  let args =
    match Fastq_sample.dep fqs with
    | SE_or_PE.Single_end fqs -> seq ~sep:" " fqs
    | Paired_end (fqs1, fqs2) ->
      seq [ seq ~sep:" " fqs1 ; string " " ; seq ~sep:" " fqs2 ]
  in
  Workflow.shell ~descr:"fastq_screen" ~np:threads ~mem:(Workflow.int (3 * 1024)) [
    mkdir_p dest ;
    cmd "fastq_screen" ~img [
      string "--aligner bowtie2" ;
      option (opt "--bowtie2" string) bowtie2_opts ;
      option (opt "--filter" (filter_expr "")) filter ;
      option (flag string "--illumina1_3") illumina ;
      option (flag string "--nohits") nohits ;
      option (opt "--pass" int) pass ;
      option (opt "--subset" int) subset ;
      option (flag string "--tag") tag ;
      opt "--threads" Fn.id np ;
      option (opt "--top" top_expr) top ;
      args ;
      string "--conf" ; file_dump (configuration genomes) ;
      opt "--outdir" Fn.id dest ;
    ] ;
    if lightweight then rm_rf ( dest // "*.fastq" )
    else cmd "" [] ;
    mv ( dest // "*_screen.html"  ) ( dest // "report_screen.html") ;
  ]

let html_report x = Workflow.select x [ "report_screen.html" ]
