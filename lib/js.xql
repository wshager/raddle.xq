xquery version "3.1";

module namespace core="http://raddle.org/javascript";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare variable $core:typemap := map {
	"integer": 0,
	"string": 0,
	"item": 0,
	"anyURI": 0,
	"map": 2,
	"function": 2
};

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

declare function core:instance-of($a,$b) {
	concat("(",$a," instanceof ",$b,")")
};

declare %private function core:is-fn-seq($value) {
	if($value instance of xs:string) then "&#07;isFnSeq_1($value)" else
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

declare function core:process-args($frame,$args){
	if($frame instance of xs:string) then
		"&#07;processArgs_2($frame,$args)"
	else
		let $args2 :=
			a:fold-left-at($args,[],function($pre,$arg,$at){
				if($arg instance of array(item()?)) then
					let $name := $frame("$caller")
					let $is-params := ($name = ("core:define-private#6","core:define#6") and $at = 4) or ($name eq "core:function#3" and $at = 1)
					let $is-body := ($name = ("core:define-private#6","core:define#6") and $at = 6) or ($name eq "core:function#3" and $at = 3)
					return
						array:append($pre,
							if($is-params or (core:is-fn-seq($arg) = false() and $is-body = false())) then
								a:for-each-at($arg,function($_,$at){
									if($_ instance of array(item()?)) then
										core:transpile($_, $frame)
									else
										core:process-value($_,map:put($frame,"$at",$at))
								})
							else
								core:transpile($arg, $frame, $is-body and core:is-fn-seq($arg))
						)
				else if($arg instance of map(xs:string,item()?)) then
					if($arg("name") eq "" and array:size($pre) > 1) then
						if($pre($at - 1) instance of array(item()?)) then
							a:put($pre,$at - 1,array:append($pre($at - 1),$arg))
						else
							a:put($pre,$at - 1,[$pre($at - 1),$arg])
					else
						array:append($pre,core:process-value($arg,$frame))
				else if($arg eq ".") then
					array:append($pre,"$_0")
				else if($arg eq "$") then
					array:append($pre,$frame)
				else if(matches($arg,"^\$[" || $raddle:ncname || "]+$")) then
					array:append($pre,if(matches($arg,"^\$\p{N}")) then
						replace($arg,"^\$","\$_")
					else
						$arg)
				else if(matches($arg,"^[" || $raddle:ncname || "]?:?[" || $raddle:ncname || "]+#(\p{N}|N)+")) then
					array:append($pre,$arg)
				else if(matches($arg,"^_[" || $raddle:suffix || "]?$")) then
					array:append($pre,replace($arg,"^_","_" || $frame("$at")))
				else
					array:append($pre,core:serialize($arg,$frame))
			})
(:		let $n :=:)
(:		a:for-each-at($args2, function($_,$i){:)
(:			try { console:log(($args($i)," -> ",$_)) } catch * { () }:)
(:		}):)
		return $args2
};

declare function core:op($op,$b){
	core:op($op,"",$b)
};

declare function core:op($op,$a,$b){
	concat($a," ",$core:operator-map($op)," ",$b)
};

declare function core:filter($a,$b){
	concat($a,$b)
};

declare function core:geq($a,$b) {
	(: TODO create a sequence-type general comp :)
	$a || " == " || $b
};

declare function core:array($seq) {
	string-join(array:flatten($seq),",")
};

declare function core:typegen2($type,$keytype,$valtype) {
	core:cap($type)
};

declare function core:typegen2($type,$seq) {
	if($type eq "map") then
		core:map($seq)
	else
		()
};

declare function core:typegen2($type,$keytype,$valtype,$body) {
	if($type eq "map") then
		core:map($keytype,$valtype,$body)
	else
		core:function($keytype,$valtype,$body)
};

declare function core:map($keytype,$valtype,$seq) {
	core:map($seq)
};

declare function core:map($seq) {
	concat("&#07;{",a:fold-left-at($seq,"",function($pre,$cur,$at){
		concat($pre,if($at mod 2 = 1) then concat(if($at>1) then "," else "",$cur,":",$seq($at+1)) else "")
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
		let $head := array:head($tree)
		let $val := core:process-value($head,$frame)
		let $is-seq := $val instance of array(item()?)
		let $val :=
			if($is-seq) then
				if($top) then
					(: assume this is a let-return seq :)
					concat("(",a:fold-left-at($val,"",function($pre,$cur,$at){
						concat($pre,if($at>1) then ",&#10;&#13;" else "",$cur)
					}),")")
				else
					core:serialize($val,$frame)
			else
				$val
		return core:transpile(array:tail($tree),$frame,$top,concat($ret,if($at > 1 and $is-seq = false()) then if($top) then "&#10;&#13;" else "," else "",$val),$at + 1)
	else if($at = 1) then
		"nil_0()"
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
					let $is-type := $local = map:keys($core:typemap)
					let $is-op := map:contains($core:operator-map,$local)
					let $s := if($is-type or $is-op) then $s + 1 else $s
					let $frame := map:put($frame,"$caller",concat($name,"#",$s))
					let $args := core:process-args($frame,$args)
					let $args :=
						if($is-type or $is-op) then
							(: TODO append suffix :)
							array:insert-before($args,1,$local)
						else
							$args
					let $args :=
						a:for-each($args,function($_){
							if($_ instance of array(item()?) and array:size($_)>1 and $_(2) instance of map(xs:string,item()?) and $_(2)("name") eq "") then
(:								let $n := console:log($_) return:)
								core:serialize($_,$frame)
							else
								$_
						})
					let $s := array:size($args)
					let $fn :=
						if($is-type) then
							(: call typegen/constructor :)
(:							let $n := console:log($args) return:)
							let $a := $core:typemap($local)
							let $f := concat("core:typegen",if($a > 0) then $a else "")
							return function-lookup(QName("http://raddle.org/javascript", $f),$s)
						else if($is-op) then
							function-lookup(QName("http://raddle.org/javascript", "core:op"),$s)
						else
							function-lookup(QName("http://raddle.org/javascript", $name),$s)
					let $n := if(empty($fn)) then console:log(($name,$s)) else ()
					return apply($fn,$args)
				else if($name eq "") then
					core:process-args(map:put($frame,"$caller",""),$args)
				else
					let $frame := map:put($frame,"$caller",concat($name,"#",$s))
					let $args := core:process-args($frame,$args)
					let $ret := core:serialize($args,$frame)
(:						a:fold-left-at($args,"",function($pre,$cur,$at){:)
(:							let $n := console:log($cur):)
(:							let $is-seq := $cur instance of array(item()?) or ($cur instance of map(xs:string, item()?) and $cur("name") eq ""):)
(:							return concat($pre,:)
(:								if($at>1 and $is-seq=false()) then "," else "",:)
(:								if($is-seq) then core:serialize($cur,$frame) else $cur:)
(:							):)
(:						}):)
					return
						(: FIXME add default fn ns prefix :)
						let $f :=
						if(matches($name,"^(\$.*)$|^([^#]+#[0-9]+)$")) then
								core:convert($name)
							else
								core:function-name($name,$s,"fn")
(:						let $n := console:log($f):)
						return concat($f,$ret)
		else
			if(matches($value,"^_[" || $raddle:suffix || "]?$")) then
				replace($value,"^_","\$_" || $frame("$at"))
			else
				core:serialize($value,$frame)
};

declare %private function core:is-current-module($frame,$name){
	"&#07;isCurrentModule_2($frame,$name)"
};

declare function core:concat($a,$b){
	$a || " + " || $b
};

declare function core:convert($string){
	if(matches($string,"&#07;")) then
		replace($string,"&#07;","")
	else if(matches($string,"^(\$.*)$|^([^#]+#[0-9]+)$")) then
		core:cc(replace($string,"#","_"))
	else if(matches($string,"^(&quot;[^&quot;]*&quot;)$")) then
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
		"(" || a:fold-left-at($value,"",function($pre,$cur,$at){
			let $is-seq := ($cur instance of map(xs:string, item()?) and $cur("name") eq "")
			return concat($pre,
				if($at>1 and $is-seq=false()) then "," else "",
				core:serialize($cur,$params)
			)
		}) || ")"
	else
		core:convert($value)
};

declare function core:resolve-function($frame,$name){
	"&#07;resolveFunction_2($frame,$name)"
};

declare function core:resolve-function($frame,$name,$self){
	"&#07;resolveFunction_3($frame,$name,$self)"
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

declare function core:module($frame,$prefix,$ns,$desc) {
	concat("/*module namespace ", core:clip($prefix), "=", $ns, ";&#10;&#13;",$desc,"*/")
};

declare function core:import($frame,$prefix,$ns) {
	if($frame instance of xs:string) then
		"import_3($frame,$prefix,$ns)"
	else
		concat("import * as ", core:clip($prefix), " from ", $ns)
};

declare function core:import($frame,$prefix,$ns,$loc) {
	if($frame instance of xs:string) then
		"import_4($frame,$prefix,$ns)"
	else
		concat("import * as ", core:clip($prefix), " from ", $loc, "")
};

declare function core:function-name($name,$arity,$default-prefix){
	let $p := tokenize($name,":")
	return concat("&#07;",$p[last() - 1],if($p[last() - 1]) then "" else $default-prefix,".",core:cc($p[last()]),"_",$arity)
};

declare function core:cc($name){
	let $p := tokenize($name,"\-")
	return head($p) || string-join(for-each(tail($p),function($_){
		let $c := string-to-codepoints($_)
		return concat(upper-case(codepoints-to-string(head($c))),codepoints-to-string(tail($c)))
	}))
};

declare function core:define-private($frame,$name,$def,$args,$type,$body) {
	core:define($frame,$name,$def,$args,$type,$body,true())
};

declare function core:define($frame,$name,$def,$args,$type,$body) {
	core:define($frame,$name,$def,$args,$type,$body,false())
};

declare function core:define($frame,$name,$def,$args,$type,$body,$private) {
	let $ret := string-join(array:flatten($args),",")
	return concat(if($private) then "" else "export ","function ",core:cc(tokenize(core:clip($name),":")[last()]),"_",array:size($args),"(",$ret,") /*",$type,"*/ {&#10;&#13;return ",replace($body,"&#07;",""),";&#10;&#13;}")
};

declare function core:describe($frame,$name,$def,$args,$type){
	core:map([])
};

declare function core:function($args,$type,$body) {
	let $args := string-join(array:flatten($args),",") return
	concat("function(",$args,") /*",$type,"*/ {&#10;&#13;return ",$body,";&#10;&#13;}")
};

declare function core:cap($str){
	let $cp := string-to-codepoints($str)
	return codepoints-to-string((string-to-codepoints(upper-case(codepoints-to-string(head($cp)))),tail($cp)))
};

declare function core:typegen($type) {
	core:cap($type)
};

declare function core:filter-at($a,$fn) {
	"filterAt_2(" || $a || "," || $fn || ")"
};

declare function core:if($a,$b,$c){
	concat("&#07;(",$a," ? ",$b," : ",$c,")")
};

declare function core:typegen($type,$val) {
	"new " || core:typegen($type) || "(" || $val || ")"
};

declare function core:clip($name){
	if(matches($name,"^&quot;.*&quot;$")) then raddle:clip-string($name) else $name
};

declare function core:typegen($type,$frame,$name){
	"$" || replace(core:clip($name),"\$","")
};

declare function core:typegen($type,$frame,$name,$val){
	core:typegen($type,$frame,$name,$val,"")
};

declare function core:typegen($type,$frame,$name,$val,$suffix) {
	let $name := core:clip($name)
	let $type := core:cap($type)
	return
		if($val) then
			"$" || $name || " = new " || $type || "(" || $val || ")"
		else
			$name || " /* " || $type || $suffix || " */"
};
