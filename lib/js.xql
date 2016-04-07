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

declare %private function core:is-fn-seq($value) {
	if(array:size($value) eq 0) then
		()
	else
		distinct-values(array:flatten(
			array:for-each($value,function($_){
				if($_ instance of map(xs:string, item()?)) then
					(: only check strings in sequence :)
					core:is-fn-seq($_("args"))
				else
					$_ instance of xs:string and matches($_,"^\.$|^\$$")
			})
		)) = true()
};

declare function core:process-args($frame,$name,$args){
	a:for-each-at($args,function($arg,$at){
		if($arg instance of array(item()?)) then
			let $n := console:log(($name,$at))
			let $is-body := ($name eq "core:define#6" and $at = 6) or ($name eq "core:function#3" and $at = 3)
			return
			if(core:is-fn-seq($arg) or $is-body) then
				core:transpile($arg, $frame, $is-body and core:is-fn-seq($arg))
			else
				a:for-each-at($arg,function($_,$at){
					if($_ instance of array(item()?)) then
						core:transpile($_, $frame)
					else
						core:process-value($_,map:put($frame,"$at",$at))
				})
		else if($arg instance of map(xs:string,item()?)) then
			core:process-value($arg,$frame)
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

declare function core:op($op,$b){
	core:op($op,"",$b)
};

declare function core:op($op,$a,$b){
	concat($a,$core:operator-map($op),$b)
};

declare function core:filter($a,$b){
	concat($a,$b)
};

declare function core:geq($a,$b) {
	(: TODO create a sequence-type general comp :)
	$a || " == " || $b
};

declare function core:map($seq) {
	concat("{",a:fold-left-at($seq,"",function($pre,$cur,$at){
		concat($pre,if($at mod 0) then concat(if($at>1) then "," else "",$cur,":",$seq($at+1)) else "")
	}),"}")
};

declare function core:transpile($value,$frame) {
	core:transpile($value,$frame,false())
};

declare function core:transpile($value,$frame,$top){
	core:transpile($value,$frame,$top,"",1)
};

declare function core:transpile($tree,$frame,$top,$ret,$at){
	(: TODO mirror n:eval :)
	(: TODO cleanup into process-args :)
	if(array:size($tree) > 0) then
		let $frame := map:put($frame,"$at",$at)
		let $val := core:process-value(array:head($tree),$frame)
		let $is-seq := $val instance of array(item()?)
		let $val :=
			if($is-seq) then
				if($top) then
					(: assume this is a let-return seq :)
					a:fold-left-at($val,"",function($pre,$cur,$at){
						concat($pre,if($at>1) then ";&#10;&#13;" else "",if($at < array:size($val)) then "" else "return ",$cur)
					})
				else
					core:serialize($val,$frame)
			else
				$val
		return core:transpile(array:tail($tree),$frame,$top,concat($ret,if($at > 1 and $is-seq = false()) then if($top) then ";&#10;&#13;" else "," else "",$val),$at + 1)
	else
		$ret
};

declare function core:process-value($value,$frame){
		if($value instance of map(xs:string,item()?)) then
			let $args := $value("args")
			let $s := array:size($args)
			let $name := $value("name")
			return
				if(matches($name,"^core:[" || $raddle:ncname || "]+$")) then
					let $local := replace($name,"^core:","")
					let $is-type := $local = $core:types
					let $is-op := map:contains($core:operator-map,$local)
					let $s := if($is-type or $is-op) then $s + 1 else $s
					let $args := core:process-args($frame,concat($name,"#",$s),$args)
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
					return apply($fn,$args)
				else if($name eq "") then
					core:process-args($frame,"",$args)
				else
					let $args := core:process-args($frame,concat($name,"#",$s),$args)
					let $ret :=
						a:fold-left-at($args,"",function($pre,$cur,$at){
							let $is-seq := $cur instance of array(item()?)
							return concat($pre,
								if($at>1 and $is-seq=false()) then "," else "",
								if($is-seq) then core:serialize($cur,$frame) else $cur
							)
						})
					return
						(: FIXME properly handle function :)
						concat(
							if(matches($name,":")) then
								core:function-name($name,$s)
							else
								core:cc($name),
						"(",$ret,")")
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
	"string": "String",
	"item": "Item"
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

declare function core:function-name($name,$arity){
	let $p := tokenize($name,":")
	return concat($p[last() - 1],if($p[last() - 1]) then "." else "",core:cc($p[last()]),"_",$arity)
};

declare function core:cc($name){
	let $p := tokenize($name,"\-")
	return head($p) || string-join(for-each(tail($p),function($_){
		let $c := string-to-codepoints($_)
		return concat(upper-case(codepoints-to-string(head($c))),codepoints-to-string(tail($c)))
	}))
};


declare function core:define($frame,$name,$def,$args,$type,$body) {
	let $ret := string-join(array:flatten($args),",") return
	concat("export function ",core:function-name($name,array:size($args)),"(",$ret,") /*",$type,"*/ {&#10;&#13;",$body,"&#10;&#13;}")
};

declare function core:describe($frame,$name,$def,$args,$type){
	core:map([])
};

declare function core:function($args,$type,$body) {
	let $args := string-join(array:flatten($args),",") return
	concat("function(",$args,") /*",$type,"*/ {&#10;&#13;",$body,"&#10;&#13;}")
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
	"$" || core:clip($name)
};

declare function core:typegen($type,$frame,$name,$val){
	core:typegen($type,$frame,$name,$val,"")
};

declare function core:typegen($type,$frame,$name,$val,$suffix) {
	let $name := core:clip($name)
	let $type := $core:typemap($type)
	return
		if($val) then
			"let $" || $name || " = new " || $type || "(" || $val || ")"
		else
			$name || " /* " || $type || $suffix || " */"
};
