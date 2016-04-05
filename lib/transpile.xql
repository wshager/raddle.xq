xquery version "3.1";

module namespace core="http://raddle.org/transpile";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace xq="http://raddle.org/xquery" at "xq.xql";
import module namespace js="http://raddle.org/javascript" at "js.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare variable $core:types := ("integer","string");

declare variable $core:auto-converted := map {
	"true" := "true()",
	"false" := "false()",
	"null" := "()",
	"undefined" := "()",
	"Infinity" := "1 div 0e0",
	"-Infinity" := "-1 div 0e0"
};

declare function core:xq-version($frame,$version){
	if($frame("$transpile") eq "xq") then
		"xquery version &quot;" || $version || "&quot;;"
	else if($frame("$transpile") eq "js") then
		"/* xquery version " || $version || " */"
	else
		()
};

declare function core:module($frame,$prefix,$ns,$desc) {
	if($frame("$transpile") eq "xq") then
		xq:module($prefix, $ns, $desc)
	else if($frame("$transpile") eq "js") then
		js:module($prefix, $ns, $desc)
	else
		()
};

declare function core:import($frame,$prefix,$ns) {
	if($frame("$transpile") eq "xq") then
		xq:import($prefix, $ns)
	else if($frame("$transpile") eq "js") then
		js:import($prefix, $ns)
	else
		()
};

declare function core:import($frame,$prefix,$ns,$location) {
	if($frame("$transpile") eq "xq") then
		xq:import($prefix, $ns, $location)
	else if($frame("$transpile") eq "js") then
		js:import($prefix, $ns, $location)
	else
		()
};

declare function core:define($frame,$name,$desc,$args,$type,$body) {
	if($frame("$transpile") eq "xq") then
		xq:define($name, $desc, $args, $type, $body)
	else if($frame("$transpile") eq "js") then
		js:define($name, $desc, $args, $type, $body)
	else
		()
};

declare function core:function($args,$type,$body) {
	let $n := console:log($body) return
	if($frame("$transpile") eq "xq") then
		xq:function($args, $type, $body)
	else if($frame("$transpile") eq "js") then
		js:function($args, $type, $body)
	else
		()
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

(:declare function core:transpile($value,$frame,$top){:)
(:	core:transpile($value,$frame,$top,1):)
(:};:)

declare function core:transpile($value,$frame,$top){
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
				let $fn := function-lookup(QName("http://raddle.org/transpile", $name),array:size($args))
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

declare function core:typegen($type) {
	if($frame("$transpile") eq "xq") then
		xq:typegen($type)
	else if($frame("$transpile") eq "js") then
		js:typegen($type)
	else
		()
};

declare function core:typegen($type,$val) {
	if($frame("$transpile") eq "xq") then
		xq:typegen($type,$val)
	else if($frame("$transpile") eq "js") then
		js:typegen($type,$val)
	else
		()
};

declare function core:typegen($frame,$type,$name) {
	core:typegen($frame,$type,$name,())
};

declare function core:typegen($frame,$type,$name,$val) {
	let $name := concat("$",if(matches($name,"^&quot;.*&quot;$")) then raddle:clip-string($name) else $name)
	return
		if($frame("$transpile") eq "xq") then
			xq:typegen($type, $name, $val)
		else if($frame("$transpile") eq "js") then
			js:typegen($type, $name, $val)
		else
			()
};

declare function core:integer() {
	core:typegen("integer",())
};

declare function core:integer($frame,$name) {
	core:typegen($frame,"integer",$name)
};

declare function core:integer($frame,$name,$val) {
	core:typegen($frame,"integer",$name,$val,$frame)
};

declare function core:item(){
	core:typegen("item")
};

declare function core:item($val){
	core:typegen("item",$val)
};


declare function core:item($frame,$name){
	core:typegen($frame,"item",$name)
};

declare function core:item($frame,$name,$val){
	core:typegen($frame,"item",$name,$val)
};
(::)
(:declare function core:integer($name,$val,$context) {:)
(:	core:typegen("xs:integer",$name)($val,$context):)
(:};:)
(::)
(:declare function core:integer($name,$val,$body,$context) {:)
(:	core:typegen("xs:integer",$name,$body)($val,$context):)
(:};:)
(::)
(:declare function core:string() {:)
(:	"xs:string":)
(:};:)
(::)
(:declare function core:string($name) {:)
(:	core:typegen("xs:string",$name):)
(:};:)
(::)
(:declare function core:string($name,$val) {:)
(:	core:typegen("xs:string",$name,$val):)
(:};:)
(::)
(:declare function core:string($name,$val,$context) {:)
(:	core:typegen("xs:string",$name)($val,$context):)
(:};:)
(::)
(:declare function core:integer($name,$val,$body,$context) {:)
(:	core:typegen("xs:string",$name,$body)($val,$context):)
(:};:)
