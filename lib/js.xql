xquery version "3.1";

module namespace core="http://raddle.org/javascript";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare variable $core:types := (
	"integer",
	"string",
	"item"
);

declare variable $core:operator-map := map {
	"or": "||",
	"and": "&amp;&amp;",
	"eq": "==",
	"ne": "!=",
	"lt": "<",
	"le": "<=",
	"gt": ">",
	"ge": ">=",
	"add": "+",
	"subtract": "-",
	"multiply": "*",
	"div": "/",
	"mod": "%"
};

declare variable $core:auto-converted := map {
	"true" := "true()",
	"false" := "false()",
	"null" := "()",
	"undefined" := "()",
	"Infinity" := "1 div 0e0",
	"-Infinity" := "-1 div 0e0"
};

declare function core:xq-version($frame,$version){
	"/* xquery version " || $version || " */"
};

declare function core:process-args($frame,$name,$args){
	a:for-each($args,function($arg){
		if($arg instance of array(item()?)) then
			a:for-each-at($arg,function($_,$at){
				core:transpile($_,map:put($frame,"$at",$at),$name = "function")
			})
		else if($arg instance of map(xs:string,item()?)) then
			core:transpile($arg,$frame,$name = "function" and $arg("name") = $core:types)
		else if($arg eq ".") then
			"$_0"
		else if($arg eq "$") then
			$frame
		else if(matches($arg,"^\$[" || $raddle:ncname || "]+$")) then
			if(matches($arg,"^\$\p{N}")) then
				replace($arg,"^\$","\$_")
			else
				$arg
		else if(matches($arg,"^[" || $raddle:ncname || "]?:?[" || $raddle:ncname || "]+#(\p{N}|N)+")) then
			$arg
		else if(matches($arg,"^_[" || $raddle:suffix || "]?$")) then
			replace($arg,"^_","_" || $frame("$at"))
		else
			core:serialize($arg,$frame)
	})
};

declare function core:transpile($value,$frame) {
	core:transpile($value,$frame,false())
};

declare function core:op($op,$b){
	core:op($op,"",$b)
};

declare function core:op($op,$a,$b){
	concat($a,$op,$b)
};

declare function core:filter($a,$b){
	concat($a,$b)
};

declare function core:geq($a,$b) {
	(: TODO create a sequence-type general comp :)
	$a || " == " || $b
};

declare function core:transpile($value,$frame,$top){
	(: TODO mirror n:eval :)
	if($value instance of array(item()?)) then
		a:fold-left-at($value,"",function($pre,$cur,$i){
			concat($pre,if($i>1) then if($top) then ";&#10;" else "," else "",core:transpile($cur,$frame,$top))
		})
	else if($value instance of map(xs:string,item()?)) then
		let $args := $value("args")
		let $name := $value("name")
		let $args := core:process-args($frame,$name,$args)
		return
			if(matches($name,"^core:[" || $raddle:ncname || "]+$")) then
				let $local := replace($name,"^core:","")
				let $is-type := $local = $core:types
				let $is-op := map:contains($core:operator-map,$local)
				let $args :=
					if($is-type or $is-op) then
						(: TODO append suffix :)
						array:insert-before($args,1,$local)
					else
						$args
				let $fn :=
					if($is-type) then
						(: call typegen/constructor :)
						function-lookup(QName("http://raddle.org/javascript", "core:typegen"),array:size($args))
					else if($is-op) then
						function-lookup(QName("http://raddle.org/javascript", "core:op"),array:size($args))
					else
						function-lookup(QName("http://raddle.org/javascript", $name),array:size($args))
				let $n := if( exists($fn)) then () else
					console:log($value)
				return apply($fn,$args)
			else if($name eq "") then
				a:for-each($args,function($arg){
					core:transpile($arg,$frame)
				})
			else
				replace($name,":",".") || "(" || core:transpile($args,$frame) || ")"
	else
		if(matches($value,"^_[" || $raddle:suffix || "]?$")) then
			replace($value,"^_","\$_" || $frame("$at"))
		else
			core:serialize($value,$frame)
};

declare function core:and($a,$b){
	$a || " &amp;&amp; " || $b
};

declare function core:eq($a,$b){
	$a || " == " || $b
};

declare function core:concat($a,$b){
	$a || " + " || $b
};

declare function core:convert($string){
	if(matches($string,"^_[\?\*\+]?$|[\?\*\+:]+|^(\$.*)$|^([^#]+#[0-9]+)$|^(&quot;[^&quot;]*&quot;)$")) then
		$string
	else if(map:contains($core:auto-converted,$string)) then
		$core:auto-converted($string)
	else
		if(string(number($string)) = "NaN") then
			"&quot;" || util:unescape-uri($string,"UTF-8") || "&quot;"
		else
			number($string)
};

declare function core:serialize($value,$params){
	if($value instance of map(xs:string, item()?)) then
		$value("name") || (if(map:contains($value,"args")) then core:serialize($value("args"),$params) else "()") || (if(map:contains($value,"suffix")) then $value("suffix") else "")
	else if($value instance of array(item()?)) then
		"(" || string-join(array:flatten(array:for-each($value,function($val){
			core:serialize($val,$params)
		})),",") || ")"
	else
		core:convert($value)
};

declare function core:resolve-function($frame,$name,$self){
	(: TODO move to bindings :)
	if($self) then
		$name
	else
		let $parts := tokenize($name,":")
		let $prefix := if($parts[2]) then $parts[1] else ""
		let $module := $frame("$imports")($prefix)
		let $theirname := concat(if($module("$prefix")) then concat($module("$prefix"),":") else "", $parts[last()])
		return $theirname
};

(:declare function core:apply($frame,$name,$args){:)
(:	let $self := core:is-current-module($frame,$name):)
(:	let $f := core:resolve-function($frame, $name, $self):)
(:	let $frame := map:put($frame,"$callstack",array:append($frame("$callstack"),$name)):)
(:(:	let $n := console:log($frame("$callstack")):):)
(:	let $frame := map:put($frame,"$caller",$name):)
(:	return:)
(:		if($self) then:)
(:			$f(core:process-args($frame,$args)):)
(:		else:)
(:			apply($f,core:process-args($frame,$args)):)
(:};:)

declare variable $core:typemap := map {
	"integer": "Number",
	"string": "String"
};

declare function core:module($frame,$prefix,$ns,$desc) {
	concat("/*module namespace ", core:clip($prefix), "=", $ns, ";&#10;",$desc,"*/")
};

declare function core:import($frame,$prefix,$ns) {
	concat("import * as ", core:clip($prefix), " from ", $ns)
};

declare function core:import($frame,$prefix,$ns,$loc) {
	concat("import * as ", core:clip($prefix), " from ", $loc, "")
};


declare function core:cc($name){
	let $p := tokenize(replace($name,"#","_"),"\-")
	return head($p) || string-join(for-each(tail($p),function($_){
		let $c := string-to-codepoints($_)
		return concat(upper-case(codepoints-to-string(head($c))),codepoints-to-string(tail($c)))
	}))
};


declare function core:define($frame,$name,$def,$args,$type,$body) {
	let $args := array:for-each($args,function($_){
(:		let $n := console:log($_) return:)
		if($_ instance of array(item()?)) then
			apply(core:typegen#3,$_)
		else
			"$" || $_
	})
	let $check := string-join(array:flatten(array:for-each($args,function($_){
		concat("core.typecheck(",string-join(tokenize(replace($_,"^([^ ]*) /\* (\p{L}+)([\?\*\+]?) \*/$","$2,$1,$3"),",")[. ne ""],","),")")
	})),";")
	return concat("export function ",core:cc(tokenize($name,":")[last()]),"(",string-join(array:flatten($args),","),") /*",$type,"*/ { ",$check,"; return ",$body," };")
};

declare function core:describe($frame,$name,$def,$args,$type){
	""
};

declare function core:function($args,$type,$body) {
	let $args := array:for-each($args,function($_){
(:		let $n := console:log($_) return:)
		if($_ instance of array(item()?)) then
			apply(core:typegen#3,$_)
		else
			"$" || $_
	})
	let $check := string-join(array:flatten(array:for-each($args,function($_){
		concat("core.typecheck(",string-join(tokenize(replace($_,"^([^ ]*) /\* (\p{L}+)([\?\*\+]?) \*/$","$2,$1,$3"),",")[. ne ""],","),")")
	})),";")
	return concat("function(",string-join(array:flatten($args),","),") /*",$type,"*/ { ",$check,"; return ",$body," };")
};

declare function core:typegen($type) {
	core:typegen($type,"")
};

declare function core:typegen($type,$val) {
	"new " || $core:typemap($type) || "(" || $val || ")"
};

declare function core:if($a,$b,$c){
	concat("if(",$a,") { return ",$b,"; } else {return ",$c,";}")
};

declare function core:clip($name){
	if(matches($name,"^&quot;.*&quot;$")) then raddle:clip-string($name) else $name
};

declare function core:typegen($type,$frame,$name){
	core:clip($name)
};

declare function core:typegen($type,$frame,$name,$val){
	core:typegen($type,$frame,$name,$val,"")
};

declare function core:typegen($type,$frame,$name,$val,$suffix) {
	let $name := core:clip($name)
	let $type := $core:typemap($type)
	return
		if($val) then
			"let $" || $name || " = core.typecheck(" || $type || "," || $val || "," || $suffix || ");"
		else
			$name || " /* " || $type || $suffix || " */"
};
