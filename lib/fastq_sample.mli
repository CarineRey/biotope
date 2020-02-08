open Bistro

type t =
  | Fq of fastq file SE_or_PE.t
  | Fq_gz of fastq gz file SE_or_PE.t

val is_single_end : t -> bool

val dep : t -> Shell_dsl.template SE_or_PE.t

val explode : t list ->
  (fastq file list * fastq file list * fastq file list)
  * (fastq gz file list * fastq gz file list * fastq gz file list)

type source =
  | Fastq_url of string SE_or_PE.t
  | Fastq_gz_url of string SE_or_PE.t
  | SRA_dataset of { srr_id : string ;
                     library_type : [`single_end | `paired_end] }

module type Data = sig
  type t
  val source : t -> source
end

module Make(Data : Data) : sig
  val fastq : Data.t -> fastq file SE_or_PE.t
  val fastq_gz : Data.t -> fastq gz file SE_or_PE.t
  val fastq_sample : Data.t -> t
  val fastqc : Data.t -> FastQC.report SE_or_PE.t
end
