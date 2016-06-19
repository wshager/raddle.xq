xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat.xql";
import module namespace a="http://raddle.org/array-util" at "/db/apps/raddle.xq/lib/array-util.xql";
import module namespace console="http://exist-db.org/xquery/console";


declare function local:serialize($dict){
	serialize($dict,
		<output:serialization-parameters>
			<output:method>json</output:method>
		</output:serialization-parameters>)
};

declare function local:normalize($query,$params) {
	let $strings := analyze-string($query,"('[^']*')|(&quot;[^&quot;]*&quot;)")/*
	return xqc:normalize-query(string-join(for-each(1 to count($strings),function($i){
		if(name($strings[$i]) eq "match") then
			"$%" || $i
		else
			$strings[$i]/string()
	})),$params)
};

declare function local:find-tc($a,$name,$pos){
    for $x at $i in array:flatten($a) return
        if($x instance of map(xs:string,item()?)) then
            if($x("name") eq $name) then
                if($pos) then $pos else $i
            else
                local:find-tc($x("args"),$name,$i)
        else
            ()
};

declare function local:wrap($a,$tc,$name){
    a:for-each-at($a,function($n,$at){
        let $ismap := $n instance of map(xs:string,item()?)
        return
            if($ismap and $n("name") eq "core:iff") then
                (: expect 3 args :)
                let $args := $n("args")
                let $self := local:find-tc($args,$name,0)
                return
                    map:put($n,"args",local:wrap($args,$self,$name))
            else if($n instance of array(item()?)) then
                local:wrap($n,$tc,$name)
            else
                let $n := if($ismap) then
                    let $n := if($name and $n("name") eq $name) then map:put($n,"name","n:cont") else $n
                    return
                        if($n("name") = ("core:define","core:define-private")) then
                            map:put($n,"args",local:wrap($n("args"),(),$n("args")(2)))
                        else
                            $n
                else
                    $n
                return
                    if($at > 1 and $at ne $tc) then
                        map {
                            "name": "n:stop",
                            "args": [$n]
                        }
                    else
                        $n
     })
};



let $params := map { "$raddled" := "/db/apps/raddle.xq/raddled", "$callstack": [], "$compat": "xquery", "$transpile": "js"}

let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/raddled/xq-compat.rdl"), "utf-8")

let $query := 'declare function x:fold($a,$b,$c) {
	if(empty($a)) then
	    $b
	else
	    x:fold(tail($a),$c($b,head($a)),$c)
};'

(:return local:normalize($query,$params):)
(:return local:serialize(raddle:parse($query,$params)):)
(:return xmldb:store("/db/apps/raddle.xq/js","xq-compat.js",raddle:exec($query,$params),"text/plain"):)

let $rdl := raddle:parse($query,$params)
return raddle:transpile(local:wrap($rdl,(),()),"js",$params)

(:let $module := raddle:exec($query,$params):)
(:let $fn := $module("$exports")("test:add#2"):)
(:return $fn([2,3]):)
