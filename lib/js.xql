xquery version "3.1";

module namespace core="http://raddle.org/javascript";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare variable $core:typemap := map {
	"boolean": 0,
	"integer": 0,
	"decimal": 0,
	"string": 0,
	"item": 0,
	"anyURI": 0,
	"map": 2,
	"function": 2,
	"array": 1,
	"element": 1,
	"attribute": 1
};

declare variable $core:native := (
	"or",
	"and",
	"eq",
	"ne",
	"lt",
	"le",
	"gt",
	"ge",
	"add",
	"subtract",
	"plus",
	"minus",
	"multiply",
	"div",
	"mod",
	"geq",
	"gne",
	"ggt",
	"glt",
	"gge",
	"gle",
	"concat",
	"filter",
	"filter-at",
	"for-each",
	"for-each-at",
	"to",
	"instance-of"
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
	"/* xquery version " || $version || " */"
};

declare %private function core:is-fn-seq($value) {
	if($value instance of xs:string) then "&#07;n.isFnSeq($value)" else
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
		"&#07;n.processArgs($frame,$args)"
	else
		let $args2 :=
			a:fold-left-at($args,[],function($pre,$arg,$at){
				if($arg instance of array(item()?)) then
					let $name := $frame("$caller")
					let $is-params := ($name = ("core:define-private#6","core:define#6") and $at = 4) or ($name eq "core:function#3" and $at = 1)
					let $is-body := ($name = ("core:define-private#6","core:define#6") and $at = 6) or ($name eq "core:function#3" and $at = 3)
					let $is-fn-seq := core:is-fn-seq($arg)
					return
						array:append($pre,
							if($is-params or ($is-fn-seq = false() and $is-body = false())) then
								a:for-each-at($arg,function($_,$at){
									if($_ instance of array(item()?)) then
										core:transpile($_, $frame)
									else
										core:process-value($_,map:put($frame,"$at",$at))
								})
							else
								let $ret := core:transpile($arg, $frame, $is-body and $is-fn-seq)
								return if($is-fn-seq) then concat("(",$ret,")") else $ret
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

declare function core:native($op,$a){
	concat("&#07;n.",core:cc($op),"(",$a,")")
};

declare function core:native($op,$a,$b){
	concat("&#07;n.",core:cc($op),"(",$a,",",$b,")")
};

declare function core:array($seq) {
	concat("&#07;n.array(",$seq,")")
};

declare function core:map($keytype,$valtype,$seq) {
	core:map($seq)
};

declare function core:map($seq) {
	concat("&#07;n.map(",$seq,")")
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
		let $frame := if($head("name") eq "core:module") then map:put($frame,"$prefix",$head("args")(2)) else $frame
		let $val := core:process-value($head,$frame,$top)
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
		"n.seq()"
	else
		$ret
};

declare function core:hoist($tree){
	if($tree instance of array(item()?)) then
		a:fold-left($tree,(),function($pre,$value) {
			if($value instance of map(xs:string,item()?)) then
				let $name := $value("name")
				let $args := $value("args")
				return
					($pre,
						if(matches($name,"^core:[" || $raddle:ncname || "]+$") and replace($name,"^core:","") = map:keys($core:typemap) and array:size($args) > 1) then
							if($args(2) instance of xs:string) then
								concat("$",$args(2))
							else
								()
						else
							(),core:hoist($args))
			else if($value instance of array(item()?)) then
				($pre,core:hoist($value))
			else
				$pre
		})
	else
		()
};

declare function core:process-value($value,$frame){
	core:process-value($value,$frame,false())
};

declare function core:process-value($value,$frame,$top){
		if($value instance of map(xs:string,item()?)) then
			let $name := $value("name")
			let $args := $value("args")
			let $s := array:size($args)
			return
				if(matches($name,"^core:[" || $raddle:ncname || "]+$")) then
					let $local := replace($name,"^core:","")
					let $is-type := $local = map:keys($core:typemap)
					let $is-native := $core:native = $local
					let $s := if($is-type or $is-native) then $s + 1 else $s
					let $is-fn := ($local = ("define","define-private") and $s eq 6) or ($local eq "function" and $s eq 4)
					let $frame := map:put($frame,"$caller",concat($name,"#",$s))
					let $hoisted :=
						if($is-fn) then
							let $i := if($local = ("define","define-private")) then 6 else 3
							return core:hoist($args($i))
						else
							()
					let $args := core:process-args($frame,$args)
					let $hoisted :=
						if($is-fn) then
							let $params := array:flatten($args(if($local = ("define","define-private")) then 4 else 1))
							return
								if(exists($hoisted) and exists($params)) then
									distinct-values($hoisted[not(.=$params)])
								else
									$hoisted
						else
							()
					let $args :=
						if($local = ("define","define-private","function")) then
							let $i := if($local = ("define","define-private")) then 6 else 3
							let $body :=
								if(exists($hoisted)) then
									concat("var ",string-join(($hoisted ! core:cc(.)),","),";&#10;&#13;return ",$args($i))
								else
									concat("return ",$args($i))
							return a:put($args,$i,$body)
						else
							$args
					let $args :=
						if($is-type or $is-native) then
							(: TODO append suffix :)
							array:insert-before($args,1,$local)
						else
							$args
					let $args :=
						a:for-each($args,function($_){
							if($_ instance of array(item()?) and array:size($_)>1 and $_(2) instance of map(xs:string,item()?) and $_(2)("name") eq "") then
								core:serialize($_,$frame)
							else if($_ instance of array(item()?) and not($is-fn)) then
								concat("n.seq",core:serialize($_,$frame))
							else if($_ instance of xs:string and matches($_,"^\$")) then
								core:convert($_,$frame)
							else
								$_
						})
					let $s := array:size($args)
					let $fn :=
						if($is-type) then
							(: call typegen/constructor :)
							let $a := $core:typemap($local)
							let $f := concat("core:typegen",if($a > 0) then $a else "")
							return function-lookup(QName("http://raddle.org/javascript", $f),$s)
						else if($is-native) then
							function-lookup(QName("http://raddle.org/javascript", "core:native"),$s)
						else
							function-lookup(QName("http://raddle.org/javascript", $name),$s)
					let $n := if(empty($fn)) then console:log(($name,"#",$s,$value)) else ()
					return apply($fn,$args)
				else if($name eq "") then
					core:process-args(map:put($frame,"$caller",""),$args)
				else
					let $frame := map:put($frame,"$caller",concat($name,"#",$s))
					let $args := core:process-args($frame,$args)
					(: FIXME add check for seq calls :)
					let $ret :=
(:						core:serialize($args,$frame):)
						a:fold-left-at($args,"",function($pre,$cur,$at){
							let $is-seq := $cur instance of array(item()?)
							return concat($pre,
								if($at>1) then "," else "",
(:								if($is-seq) then let $n := console:log($cur) return "n.seq" else "",:)
								core:serialize($cur,$frame)
							)
						})
					return
						(: FIXME add default fn ns prefix :)
						let $f :=
						if(matches($name,"^(\$.*)$|^([^#]+#[0-9]+)$")) then
								concat("&#07;",core:convert($name,$frame))
							else
								core:function-name($name,$s,$frame("$prefix"),"fn")
(:						let $n := console:log($f):)
						return concat($f,"(",$ret,")")
		else
			if(matches($value,"^_[" || $raddle:suffix || "]?$")) then
				replace($value,"^_","\$_" || $frame("$at"))
			else
				core:serialize($value,$frame)
};

declare %private function core:is-current-module($frame,$name){
	"&#07;n.isCurrentModule($frame,$name)"
};

declare function core:convert($string,$frame){
	if(matches($string,"&#07;")) then
		replace($string,"&#07;","")
	else if(matches($string,"^(\$.*)$|^([^#]+#[0-9]+)$")) then
		let $parts := tokenize(core:cc(replace($string,"#","_")),":")
		return
			if(count($parts) > 1 and $parts[1] ne $frame("$prefix")) then
				concat("&#07;",replace($parts[1],"\$",""),".",$parts[2])
			else
				concat("&#07;",$parts[last()])
	else if(matches($string,"^(&quot;[^&quot;]*&quot;)$")) then
		$string
	else if(map:contains($core:auto-converted,$string)) then
		$core:auto-converted($string)
	else
		if(string(number($string)) = "NaN") then
			"&quot;" || $string || "&quot;"
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
		core:convert($value,$params)
};

declare function core:resolve-function($frame,$name){
	"&#07;n.resolveFunction($frame,$name)"
};

declare function core:resolve-function($frame,$name,$self){
	"&#07;n.resolveFunction($frame,$name,$self)"
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
		concat("import * as ", core:clip($prefix), " from ", replace($loc,"(\.xql|\.rdl)&quot;$",".js&quot;"), "")
};

declare function core:function-name($name,$arity,$prefix,$default-prefix){
	let $p := tokenize($name,":")
	let $prefix :=
		if($p[last() - 1] eq $prefix) then
				()
			else if($p[last() - 1]) then
			   $p[last() - 1]
			else
				$default-prefix
	return
		concat(
			"&#07;",
			core:cc($prefix),
			if($prefix) then "." else "",
			core:cc($p[last()]),
			"_",
			$arity
		)
};

declare function core:cc($name){
	let $p := tokenize($name,"\-")
	return head($p) || string-join(for-each(tail($p),function($_){
		let $c := string-to-codepoints($_)
		return concat(upper-case(codepoints-to-string(head($c))),codepoints-to-string(tail($c)))
	}))
};

declare function core:var($frame,$name,$def,$body){
	concat("export const ",tokenize($name,"\.")[last()]," = ",replace($body,"&#07;",""))
};

declare function core:define-private($frame,$name,$def,$args,$type,$body) {
	core:define($frame,$name,$def,$args,$type,$body,true())
};

declare function core:define($frame,$name,$def,$args,$type,$body) {
	core:define($frame,$name,$def,$args,$type,$body,false())
};

declare function core:define($frame,$name,$def,$args,$type,$body,$private) {
	let $ret := string-join(array:flatten($args),",")
	return concat(if($private) then "" else "export ","function ",core:cc(tokenize(core:clip($name),":")[last()]),"_",array:size($args),"(",$ret,") /*",$type,"*/ {&#10;&#13;",replace($body,"&#07;",""),";&#10;&#13;}")
};

declare function core:describe($frame,$name,$def,$args,$type){
	core:map([])
};

declare function core:function($args,$type,$body) {
	let $args := string-join(array:flatten($args),",") return
	concat("&#07;function(",$args,") /*",$type,"*/ {&#10;&#13;",$body,";&#10;&#13;}")
};

declare function core:cap($str){
	let $cp := string-to-codepoints($str)
	return codepoints-to-string((string-to-codepoints(upper-case(codepoints-to-string(head($cp)))),tail($cp)))
};


declare function core:if($a,$b,$c){
	concat("&#07;(",$a," ? ",$b," : ",$c,")")
};

declare function core:typegen1($type,$valtype) {
	core:cap($type)
};

declare function core:typegen1($type,$seq) {
	if($type eq "array") then
		core:array($seq)
	else
		()
};

declare function core:typegen1($type,$name,$valtype) {
	concat("n.",$type,"(",$valtype,")")
};

declare function core:select($a,$b){
	concat("n.select(",$a,",",$b,")")
};

declare function core:select-attribute($a,$b){
	concat("n.selectAttribute(",$a,",",$b,")")
};

declare function core:typegen2($type,$keytype,$valtype,$body) {
	if($type eq "map") then
		core:map($keytype,$valtype,$body)
	else
		core:function($keytype,$valtype,$body)
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

declare function core:typegen($type) {
	core:typegen($type,())
};

declare function core:typegen($type,$val) {
	"n." || $type || "(" || $val || ")"
};

declare function core:clip($name){
	if(matches($name,"^&quot;.*&quot;$")) then raddle:clip-string($name) else $name
};

declare function core:typegen($type,$frame,$name){
	"$" || replace(core:cc(core:clip($name)),"\$","")
};

declare function core:typegen($type,$frame,$name,$val){
	core:typegen($type,$frame,$name,$val,"")
};

declare function core:typegen($type,$frame,$name,$val,$suffix) {
	let $name := core:cc(core:clip($name))
	return
		if($val) then
			"$" || $name || " = n." || $type || "(" || $val || ")"
		else
			$name || " /* " || $type || $suffix || " */"
};
