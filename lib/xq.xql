xquery version "3.1";

module namespace core="http://raddle.org/transpile";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare variable $core:xs-types := (
	"integer",
	"string"
);

declare variable $core:types := (
	"array",
	"attribute",
	"comment",
	"document-node",
	"element",
	"empty-sequence",
	"function",
	"item",
	"map",
	"namespace-node",
	"node",
	"processing-instruction",
	"schema-attribute",
	"schema-element",
	"text"
);

declare variable $core:auto-converted := map {
	"true" := "true()",
	"false" := "false()",
	"null" := "()",
	"undefined" := "()",
	"Infinity" := "1 div 0e0",
	"-Infinity" := "-1 div 0e0"
};

declare function core:xq-version($frame,$version){
	"xquery version &quot;" || $version || "&quot;;"
};


declare function core:process-args($frame,$name,$args){
	a:for-each($args,function($arg){
		if($arg instance of array(item()?)) then
			a:for-each-at($arg,function($_,$at){
				core:transpile($_,map:put($frame,"$at",$at),$name = "function")
			})
		else if($arg instance of map(xs:string,item()?)) then
			core:transpile($arg,$frame,$name = "function" and $arg("name") = $core:xs-types)
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

declare function core:transpile($value,$frame,$top){
	(: TODO mirror n:eval :)
	if($value instance of array(item()?)) then
		a:fold-left($value,"",function($pre,$cur){
			$pre || "&#10;" || core:transpile($cur,$frame,$top)
		})
	else if($value instance of map(xs:string,item()?)) then
		let $args := $value("args")
		let $name :=
			if($value("name") eq "") then
				"seq"
			else
				$value("name")
		let $args := core:process-args($frame,$name,$args)
		return
			if(matches($name,"^core:[" || $raddle:ncname || "]+$")) then
				let $is-type := replace($name,"^core:","") = $core:xs-types
				let $args :=
					if($is-type) then
						(: TODO append suffix :)
						array:insert-before($args,1,replace($name,"^core:",""))
					else
						$args
				let $fn :=
					if($is-type) then
						(: call typegen/constructor :)
						function-lookup(QName("http://raddle.org/xquery", "core:typegen"),array:size($args))
					else
						function-lookup(QName("http://raddle.org/xquery", $name),array:size($args))
				let $n := console:log(($name,array:size($args), exists($fn)))
				return apply($fn,$args)
			else
				$name || "(" || string-join(array:flatten($args),",") || ")"
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

declare function core:module($prefix,$ns,$desc) {
	concat("module namespace ", raddle:clip-string($prefix), "=", $ns, ";&#10;(:",$desc,":)")
};

declare function core:import($prefix,$ns) {
	concat("import module namespace ", $prefix, "=&quot;", $ns, "&quot;;")
};

declare function core:import($prefix,$ns,$loc) {
	concat("import module namespace ", $prefix, "=&quot;", $ns, "&quot; at &quot; ", $loc, "&quot;;")
};

declare function core:define($name,$def,$args,$type,$body) {
	let $args := array:for-each($args,function($_){
		apply(core:typegen#4,$_)
	})
	return "declare function " || $name || "(" || string-join(array:flatten($args),",") || ") " || $type || " { " || $body || " };"
};

declare function core:function($args,$type,$body) {
	let $args := array:for-each($args,function($_){
		apply(core:typegen#4,$_)
	})
	return "function(" || string-join(array:flatten($args),",") || ") " || $type || " { " || $body || " };"
};

declare function core:typegen($type) {
	if($type = $core:xs-types) then $type else "xs:" || $type
};

declare function core:typegen($type,$val) {
	if($type = $core:xs-types) then
		$val
	else
		$type || "(" || $val || ")"
};

declare function core:typegen($type,$frame,$name){
	concat("$",if(matches($name,"^&quot;.*&quot;$")) then raddle:clip-string($name) else $name," as ",if($type = $core:xs-types) then "" else "xs:", $type)
};

declare function core:typegen($type,$frame,$name,$val){
	core:typegen($type,$frame,$name,$val,"")
};

declare function core:typegen($type,$frame,$name,$val,$suffix) {
	let $type := core:typegen($type)
	return
		if($val) then
			concat("let ",$name," as ",$type,$suffix," := ",$val," return ")
		else
			$name || " as xs:integer" || $suffix
};
