xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat.xql";


declare function local:serialize($dict){
	serialize($dict,
		<output:serialization-parameters>
			<output:method>json</output:method>
		</output:serialization-parameters>)
};


let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$compat" := "xquery"}

let $query := 'module namespace raddle="http://lagua.nl/lib/raddle";
declare function raddle:stringify($a,$params){
		string-join(array:flatten(array:for-each($a,function($t){
		if($t instance of map(xs:string?,item()?)) then
			concat($t("name"),"(",string-join(array:flatten(raddle:stringify($t("args"),$params)),","),")",if($t("suffix") instance of xs:string) then $t("suffix") else "")
		else if($t instance of array(item()?)) then
			concat("(",string-join(array:flatten(raddle:stringify($t,$params)),","),")")
		else
			$t
	})),",")
};'

let $query := "module($,test,test,'does test'),define($,test:add2,'add',(integer(_),integer(_)),integer(),n:add($2,$1)),define($,test:add,'add2',(integer(_),integer(_)),integer(),test:add2($1,$2))"

let $strings := analyze-string($query,"('[^']*')|(&quot;[^&quot;]*&quot;)")/*
(:let $normal := xqc:normalize-query(string-join(for-each(1 to count($strings),function($i){:)
(:		if(name($strings[$i]) eq "match") then:)
(:			"$%" || $i:)
(:		else:)
(:			$strings[$i]/string():)
(:	})),$params):)
(:return $normal:)
(:return local:serialize(raddle:parse($query,$params)):)
(:return raddle:stringify(raddle:parse($query,$params),$params):)

let $module := raddle:exec($query,$params)
let $fn := $module("$exports")("test:add#2")
return $fn([2,3])
