open Bistro

val img : Shell_dsl.container_image list

val trinity :
  ?mem:int ->
  ?no_normalize_reads:bool ->
  ?run_as_paired:bool ->
  fastq file list SE_or_PE.t ->
  fasta file

val prepare_fastq :
  int ->
  fastq file ->
  fastq file

val uniq_count_stats :
  sam file -> text file

val insilico_read_normalization :
  ?mem:int ->
  ?pairs_together:bool ->
  ?parallel_stats:bool ->
  max_cov:int ->
  fastq file SE_or_PE.t ->
  fastq file SE_or_PE.t

val get_Trinity_gene_to_trans_map :
  fasta file ->
  text file
