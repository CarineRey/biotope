open Core_kernel
open Bistro

type reference_genome =
  | Ucsc_gb of Ucsc_gb.genome
  | Fasta of { name : string ; sequence : fasta file }

module type Sample = sig
  type t
  val reference_genome : t -> reference_genome
  val all : t list
  val to_string : t -> string
  val fastq_sample : t -> Fastq_sample.t
end

module Make(S : Sample) = struct
  let genome x = match x with
    | Ucsc_gb org -> Ucsc_gb.genome_sequence org
    | Fasta fa -> fa.sequence

  let bowtie2_index x =
    genome x
    |> Bowtie2.bowtie2_build

  let mapped_reads x =
    let fq_sample = S.fastq_sample x in
    Bowtie2.bowtie2 ~maxins:800
      (bowtie2_index (S.reference_genome x))
      ~no_mixed:true
      ~no_discordant:(not (Fastq_sample.is_single_end fq_sample))
      fq_sample
    |> Samtools.(view ~output:sam ~h:true ~q:5)


  let mapped_reads_indexed_bam x =
    Samtools.indexed_bam_of_sam (mapped_reads x)

  let mapped_reads_bam x =
    mapped_reads_indexed_bam x |> Samtools.indexed_bam_to_bam

  let mapped_reads_nodup x =
    Picardtools.(
      markduplicates
        ~remove_duplicates:true
        (mapped_reads_indexed_bam x)
      |> reads
    )

  let mapped_reads_nodup_indexed x =
    mapped_reads_nodup x
    |> Samtools.indexed_bam_of_bam

  let coverage x =
    Deeptools.bamcoverage
      ~normalizeUsing:`RPKM
      ~extendreads:100
      Deeptools.bigwig
      (mapped_reads_indexed_bam x)

  let counts ~no_dups ~feature_type ~attribute_type ~gff x =
    Subread.featureCounts
      ~feature_type
      ~attribute_type
      gff
      ((if no_dups then mapped_reads_nodup else mapped_reads_bam) x)

  let reduce_se_or_pe = SE_or_PE.map ~f:(function
      | [] -> []
      | h :: _ -> [ h ]
    )

  let reduce_fastq_sample : Fastq_sample.t -> Fastq_sample.t = function
    | Fq x -> Fq (reduce_se_or_pe x)
    | Fq_gz x -> Fq_gz (reduce_se_or_pe x)

  let fastq_screen ~possible_contaminants x =
    let genomes =
      (match S.reference_genome x with
       | Ucsc_gb org as reference ->
         Ucsc_gb.string_of_genome org, genome reference
       | Fasta fa -> fa.name, fa.sequence)
      :: possible_contaminants
    in
    Fastq_screen.fastq_screen
      ~bowtie2_opts:"--end-to-end"
      ~nohits:true
      (reduce_fastq_sample (S.fastq_sample x))
      genomes
    |> Fastq_screen.html_report

  let bamstats x =
    Alignment_stats.bamstats (mapped_reads_bam x)

  let%workflow bamstats' x =
    let open Biocaml_ez in
    let open CFStream in
    Bam.with_file [%path mapped_reads_bam x] ~f:(fun _ als ->
        Stream.fold als ~init:Bamstats.zero ~f:Bamstats.update
      )

  let chrstats x =
    Alignment_stats.chrstats (mapped_reads_bam x)

  let alignment_summary =
    Alignment_stats.summary ~sample_name:S.to_string ~mapped_reads:mapped_reads_bam S.all
end
