xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat-b.xql";
import module namespace dawg="http://lagua.nl/dawg" at "../lib/dawg.xql";
import module namespace a="http://raddle.org/array-util" at "/db/apps/raddle.xq/lib/array-util.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare function local:serialize($dict) {
    serialize($dict,
		<output:serialization-parameters>
			<output:method>json</output:method>
		</output:serialization-parameters>)
};

let $compat := request:get-parameter("compat","xquery")
let $transpile := request:get-parameter("transpile","rdl")
let $query := ''

(:return local:serialize(xqc:normalize-query($query,map { "$compat": $compat, "$transpile": $transpile })):)
(:return local:serialize(xqc:analyze-chars(xqc:to-buffer($query),true())):)

let $a := [1,2,3,4]
return local:serialize(a:reduce-ahead($a,function($pre,$entry,$next,$at) {
    let $nu := console:log(map {
        "pre":$pre,
        "entry":$entry,
        "at":$at,
        "next":$next
    })
    return if($next eq 4) then $pre else $pre + $entry
},0))
