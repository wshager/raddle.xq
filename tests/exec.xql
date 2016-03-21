xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://lagua.nl/lib/raddle" at "/db/apps/raddle.xq/content/raddle.xql";

declare function local:assert($rad,$test,$val,$params) {
	let $xq := raddle:transpile($rad,$params)
	let $func := util:eval($xq)
	let $ret := $func($test)
	return
		(if(deep-equal($ret,$val)) then
			"Test successful: "
		else
			"Test failed: ") || local:serialize($test) || " yielded " || local:serialize($ret)
};

declare function local:serialize($dict){
    serialize($dict,
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)
};


let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$compat" := "xquery", "$transpile" := "xq"}

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

let $query := "module($,test,test,'does test'),function($,test:add,(integer(_),integer(_)),integer(),(integer($,x,$1),core:add($2,$x)))"

(:let $strings := analyze-string($query,"('[^']*')|(&quot;[^&quot;]*&quot;)")/*:)
(:let $normal := raddle:normalize-query(string-join(for-each(1 to count($strings),function($i){:)
(:		if(name($strings[$i]) eq "match") then:)
(:			"$%" || $i:)
(:		else:)
(:			$strings[$i]/string():)
(:	})),$params):)
(:return $normal:)
(:return local:serialize(raddle:parse($query,$params)):)
(:return raddle:stringify(raddle:parse($query,$params),$params):)
return raddle:exec($query,$params)
