open Core_kernel
open Bistro
open Bistro.Shell_dsl

let img = [ docker_image ~account:"pveber" ~name:"trinity" ~tag:"2.5.1" () ]

let dep_list fqs = list ~sep:"," dep fqs

let fqs_option_template = function
  | SE_or_PE.Single_end fqs -> opt "--single" dep_list fqs
  | Paired_end (fqs1, fqs2) ->
    seq ~sep:" " [
      opt "--left"  dep_list fqs1 ;
      opt "--right" dep_list fqs2 ;
    ]

(** https://github.com/trinityrnaseq/trinityrnaseq/wiki/Running-Trinity *)
let trinity ?(mem = 128) ?no_normalize_reads ?run_as_paired se_or_pe_fq =
  let tmp_dest = tmp // "trinity" in
  Workflow.shell ~descr:"trinity" ~np:32 ~mem:(Workflow.int (mem * 1024)) [
    mkdir_p tmp ;
    cmd "Trinity" ~img ~stdout:(string "/dev/null")[
      string "--seqType fq" ;
      fqs_option_template se_or_pe_fq ;
      option (flag string "--no_normalize_reads") no_normalize_reads ;
      option (flag string "--run_as_paired") run_as_paired ;
      opt "--CPU" ident np ;
      opt "--max_memory" ident (seq [ string "$((" ; Bistro.Shell_dsl.mem ; string " / 1024))G" ]) ;
      opt "--output" ident tmp_dest ;
    ] ;
    cmd "mv" ~img [
      tmp_dest // "Trinity.fasta" ;
      dest ;
    ]
  ]

let prepare_fastq n fq =
  Workflow.shell ~descr:"trinity.prepare_fastq" [
    pipe [
      cmd "zcat" [ dep fq ] ;
      cmd "awk" ~stdout:dest [
        sprintf {|'{ if (NR%%4==1 && !($1 ~ /.*\/%d/)) { print $1"/%d" } else { print } }'|} n n
        |> string
      ] ;
    ]
  ]

let uniq_count_stats sam =
  let sorted_sam =
    sam
    |> Samtools.bam_of_sam
    |> Samtools.sort ~on:`name
  in
  Workflow.shell ~descr:"trinity.uniq_count_stats.pl" [
    cmd "$TRINITY_HOME/util/SAM_nameSorted_to_uniq_count_stats.pl" ~img ~stdout:dest [
      dep sorted_sam ;
    ]
  ]

let fq_option_template = function
  | SE_or_PE.Single_end fqs -> opt "--single" dep fqs
  | Paired_end (fqs1, fqs2) ->
    seq ~sep:" " [
      opt "--left"  dep fqs1 ;
      opt "--right" dep fqs2 ;
    ]

let bash_app f x =
  seq ~sep:"" (string "$(" :: string f :: string " " :: x @ [ string ")" ])

(* https://github.com/trinityrnaseq/trinityrnaseq/wiki/Trinity-Insilico-Normalization#trinitys-in-silico-read-normalization *)
let insilico_read_normalization ?(mem = 128) ?pairs_together ?parallel_stats ~max_cov se_or_pe_fq =
  let trinity_cmd =
    cmd "$TRINITY_HOME/util/insilico_read_normalization.pl" [
      string "--seqType fq" ;
      fq_option_template se_or_pe_fq ;
      opt "--CPU" ident np ;
      opt "--JM" ident (seq [ string "$((" ; Bistro.Shell_dsl.mem ; string " / 1024))G" ]) ;
      opt "--max_cov" int max_cov ;
      option (flag string "--pairs_together") pairs_together ;
      option (flag string "--PARALLEL_STATS") parallel_stats ;
      opt "--output" ident tmp ;
    ]
  in
  let workflow post =
    Workflow.shell
      ~descr:"trinity.insilico_read_normalization"
      ~np:32 ~mem:(Workflow.int (mem * 1024))
      [ within_container img (and_list (trinity_cmd :: post)) ]
  in
  let mv x y = mv (bash_app "readlink" [ tmp // x ]) y in
  match se_or_pe_fq with
  | Single_end _ ->
    SE_or_PE.Single_end (workflow [ mv "single.norm.fq" dest ])
  | Paired_end _ ->
    let post = [
      mkdir_p dest ;
      mv "left.norm.fq" (dest // "left.fq") ;
      mv "right.norm.fq" (dest // "right.fq") ;
    ]
    in
    let inner = workflow post in
    Paired_end (
      Workflow.select inner ["left.fq"],
      Workflow.select inner ["right.fq"]
    )

let get_Trinity_gene_to_trans_map fa =
  Workflow.shell ~descr:"get_Trinity_gene_to_trans_map" [
    cmd "$TRINITY_HOME/util/support_scripts/get_Trinity_gene_to_trans_map.pl" ~img ~stdout:dest [
      dep fa
    ]
  ]
