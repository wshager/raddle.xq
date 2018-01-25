xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat-b.xql";
import module namespace dawg="http://lagua.nl/dawg" at "../lib/dawg.xql";
import module namespace a="http://raddle.org/array-util" at "/db/apps/raddle.xq/lib/array-util.xql";
import module namespace console="http://exist-db.org/xquery/console";


declare function local:serialize($dict){
	serialize($dict,
		<output:serialization-parameters>
			<output:method>json</output:method>
		</output:serialization-parameters>)
};


declare function local:restore-string($t,$v,$strings){
    if($t eq 7 and matches($v,"^%.*%$")) then
        $strings[position() eq xs:integer(replace($v,"%",""))]/string()
    else
        $v
};

let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$callstack": [], "$compat": "", "$transpile": "rdl"}
let $params :=
        if($params("$compat") eq "xquery") then
            map:put(map:put($params,"$operators",$xqc:operators),"$operator-map",$xqc:operator-map)
        else
            $params
let $file := "xq-compat-b"
let $dir := "lib"
let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/" || $dir || "/" || $file || ".xql"), "utf-8")

(:let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/raddled/" || $file || ".rdl"), "utf-8"):)
(:let $temp := xqc:dawg-find($xqc:operator-dawg,"d","d",$xqc:operator-map,false(),()):)
(:let $temp := xqc:dawg-find($temp(2),"e","de",$xqc:operator-map,false(),$temp(1)):)
(:return xqc:dawg-find($temp(2),"c","dec",$xqc:operator-map,false(),$temp(1)):)
(:let $rdl := json-doc("/db/apps/raddle.xq/ast/" || $file || ".json"):)
(:let $c := array { local:normalize($query,$params) }:)
(:return local:serialize($c):)
let $query := '
fold-left(to(1,10)),0,quote-typed(function((item(),item()),item()),{$(acc,$(1)),$(x,$(2)),add($(acc),$(x))}))
'
return local:serialize(xqc:normalize-query($query,$params))
(:return local:serialize(xqc:analyze-chars(xqc:to-buffer($query))):)
(:return local:serialize(dawg:traverse([map {"_k":"and","_v":400}],("n"),"a",[])):)
(:return xmldb:store("/db/apps/raddle.xq/tests","l3.json",local:serialize($c),"application/json"):)

(:return xmldb:store("/db/apps/raddle.xq","operator-trie.json",local:serialize($xqc:operator-trie),"application/json"):)

(:let $rdl := rdl:parse($query,$params):)

(:return xmldb:store("/db/apps/raddle.xq/ast",$file || ".json",local:serialize($rdl),"application/json"):)
(:return xmldb:store("/db/apps/raddle.xq/js",$file || ".js",js:transpile($rdl, $params),"text/javascript"):)
(:return xmldb:store("/db/apps/raddle.xq/raddled", $file || ".rdl",rdl:stringify($rdl,$params),"text/plain"):)

(:return local:serialize($rdl):)
(:return rdl:stringify($rdl,$params):)
(:return js:transpile($rdl,$params):)
(:return xmldb:store("/db/data/test","test.js",js:transpile($rdl, $params),"text/javascript"):)
(:let $module := rdl:exec($query,$params):)
(:let $fn := $module("$exports")("test:add#2"):)
(:return $fn([2,3]):)
