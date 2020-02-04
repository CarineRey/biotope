open Bistro

class type count_tsv = object
  inherit tsv
  method header : [`no]
  method f1 : string
  method f2 : int
end

val count :
  ?order:[`name | `position] ->
  ?mode:[`union | `intersection_strict | `intersection_nonempty] ->
  ?stranded:[` yes | `no | `reverse] ->
  ?feature_type:string ->
  ?minaqual:int ->
  ?idattribute:string ->
  [`sam of sam pworkflow | `bam of bam pworkflow] ->
  gff pworkflow ->
  count_tsv pworkflow