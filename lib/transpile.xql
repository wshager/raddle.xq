xquery version "3.1";

module namespace tp="http://raddle.org/transpile";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace xq="http://raddle.org/xquery" at "xq.xql";
import module namespace js="http://raddle.org/javascript" at "js.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare variable $tp:types := ("integer","string");

declare function tp:module($frame,$prefix,$ns,$desc) {
	if($frame("$transpile") eq "xq") then
		xq:module($prefix, $ns, $desc)
	else if($frame("$transpile") eq "js") then
		js:module($prefix, $ns, $desc)
	else
		()
};

declare function tp:function($frame,$name,$args,$type,$body) {
	let $n := console:log($body) return
	if($frame("$transpile") eq "xq") then
		xq:function($name, $args, $type, $body)
	else if($frame("$transpile") eq "js") then
		js:function($name, $args, $type, $body)
	else
		()
};

declare function tp:process-args($frame,$name,$args){
	a:for-each($args,function($arg){
		if($arg instance of array(item()?)) then
			a:for-each-at($arg,function($_,$at){
				tp:transpile($_,map:put($frame,"$at",$at),$name = "function")
			})
		else if($arg instance of map(xs:string,item()?)) then
			tp:transpile($arg,$frame,$name = "function" and $arg("name") = $tp:types)
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
			tp:serialize($arg,$frame)
	})
};

declare function tp:transpile($value,$frame) {
	tp:transpile($value,$frame,false())
};

(:declare function tp:transpile($value,$frame,$top){:)
(:	tp:transpile($value,$frame,$top,1):)
(:};:)

declare function tp:transpile($value,$frame,$top){
	if($value instance of array(item()?)) then
		a:fold-left($value,"",function($pre,$cur){
			$pre || "&#10;" || tp:transpile($cur,$frame,$top)
		})
	else if($value instance of map(xs:string,item()?)) then
		let $args := $value("args")
		let $name :=
			if($value("name") eq "") then
				"seq"
			else
				$value("name")
		let $args := tp:process-args($frame,$name,$args)
		return
			if(matches($name,"^[" || $raddle:ncname || "]+:") = false()) then
				let $fn := function-lookup(QName("http://raddle.org/transpile", $name),array:size($args))
				let $n := console:log(($name,array:size($args), exists($fn)))
				return apply($fn,$args)
			else
				$name || "(" || string-join(array:flatten($args),",") || ")"
	else
		if(matches($value,"^_[" || $raddle:suffix || "]?$")) then
			replace($value,"^_","\$_" || $frame("$at"))
		else
			tp:serialize($value,$frame)
};

declare function tp:convert($string){
	if(matches($string,"^_[\?\*\+]?$|[\?\*\+:]+|^(\$.*)$|^([^#]+#[0-9]+)$|^(&quot;[^&quot;]*&quot;)$")) then
		$string
	else if(map:contains($raddle:auto-converted,$string)) then
		$raddle:auto-converted($string)
	else
		if(string(number($string)) = "NaN") then
			"&quot;" || util:unescape-uri($string,"UTF-8") || "&quot;"
		else
			number($string)
};

declare function tp:serialize($value,$params){
	if($value instance of map(xs:string, item()?)) then
		$value("name") || (if(map:contains($value,"args")) then tp:serialize($value("args"),$params) else "()") || (if(map:contains($value,"suffix")) then $value("suffix") else "")
	else if($value instance of array(item()?)) then
		"(" || string-join(array:flatten(array:for-each($value,function($val){
			tp:serialize($val,$params)
		})),",") || ")"
	else
		tp:convert($value)
};

declare function tp:typegen($type,$name) {
	tp:typegen($type,$name,())
};

declare function tp:typegen($type,$name,$val) {
	tp:typegen($type,$name,(),())
};

declare function tp:typegen($type,$name,$val,$frame) {
	let $cp := string-to-codepoints($name)
	let $suffix :=
		if($cp[last()] = (42,43,45,63)) then
			codepoints-to-string($cp[last()])
		else
			""
	let $name := if($suffix eq "") then
		$name
	else
		codepoints-to-string(reverse(tail(reverse($cp))))
	let $name := if($name) then concat("$",if(matches($name,"^&quot;.*&quot;$")) then raddle:clip-string($name) else $name) else ()
	return
		if(empty($frame)) then
			[$type, $name, $val, $suffix]
		else
			if($frame("$transpile") eq "xq") then
				xq:typegen($type, $name, $val, $suffix)
			else if($frame("$transpile") eq "js") then
				js:typegen($type, $name, $val, $suffix)
			else
				()
};

declare function tp:integer() {
	tp:typegen("integer",())
};

declare function tp:integer($name) {
	tp:typegen("integer",$name)
};

declare function tp:integer($name,$val) {
	tp:typegen("integer",$name,$val)
};

declare function tp:integer($frame,$name,$val) {
	tp:typegen("integer",$name,$val,$frame)
};
(::)
(:declare function tp:integer($name,$val,$context) {:)
(:	tp:typegen("xs:integer",$name)($val,$context):)
(:};:)
(::)
(:declare function tp:integer($name,$val,$body,$context) {:)
(:	tp:typegen("xs:integer",$name,$body)($val,$context):)
(:};:)
(::)
(:declare function tp:string() {:)
(:	"xs:string":)
(:};:)
(::)
(:declare function tp:string($name) {:)
(:	tp:typegen("xs:string",$name):)
(:};:)
(::)
(:declare function tp:string($name,$val) {:)
(:	tp:typegen("xs:string",$name,$val):)
(:};:)
(::)
(:declare function tp:string($name,$val,$context) {:)
(:	tp:typegen("xs:string",$name)($val,$context):)
(:};:)
(::)
(:declare function tp:integer($name,$val,$body,$context) {:)
(:	tp:typegen("xs:string",$name,$body)($val,$context):)
(:};:)
