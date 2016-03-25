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

(:let $query := util:binary-to-string(util:binary-doc("/db/apps/raddle.xq/lib/core.xql"), "utf-8"):)
let $query := 'declare function core:process-args($frame,$args){
	let $n: = console:log($args) return
	a:for-each($args,function($arg){
		if($arg instance of array(item()?)) then
			(: check: composition or sequence? :)
			let $fn-seq := core:is-fn-seq($arg)
			return
				if($fn-seq) then
					n:eval($arg)
				else
					a:for-each($arg,function($_){
						n:eval($_)
					})
		else if($arg instance of map(xs:string,item()?)) then
			n:eval($arg)
		else if($arg eq ".") then
			$frame("0")
		else if($arg eq "$") then
			$frame
		else if(matches($arg,concat("^\$[",$raddle:ncname,"]+$"))) then
			(: retrieve bound value :)
			$frame(replace($arg,"^\$",""))
		else if(matches($arg,concat("^[",$raddle:ncname,"]?:?[",$raddle:ncname,"]+#(\p{N}|N)+"))) then
			core:resolve-function($frame,$arg)
		else
			$arg
	})
};'


(:let $query := "module($,test,test,'does test'),define($,test:add2,'add',(integer(_),integer(_)),integer(),n:add($2,$1)),define($,test:add,'add2',(integer(_),integer(_)),integer(),test:add2($1,$2))":)

let $strings := analyze-string($query,"('[^']*')|(&quot;[^&quot;]*&quot;)")/*
let $normal := xqc:normalize-query(string-join(for-each(1 to count($strings),function($i){
		if(name($strings[$i]) eq "match") then
			"$%" || $i
		else
			$strings[$i]/string()
	})),$params)
return $normal
(:return local:serialize(raddle:parse($query,$params)):)
(:return raddle:stringify(raddle:parse($query,$params),$params):)

(:let $module := raddle:exec($query,$params):)
(:let $fn := $module("$exports")("test:add#2"):)
(:return $fn([2,3]):)
