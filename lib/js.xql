xquery version "3.1";

module namespace core="http://raddle.org/javascript";

import module namespace raddle="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";
import module namespace console="http://exist-db.org/xquery/console";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare function local:serialize($dict){
	serialize($dict,
		<output:serialization-parameters>
			<output:method>json</output:method>
		</output:serialization-parameters>)
};

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
	if($value instance of xs:string) then "n.isFnSeq($value)" else
	if(array:size($value) eq 0) then
		()
	else
		array:flatten(
			array:for-each($value,function($_){
				if($_ instance of map(xs:string, item()?)) then
					(: only check strings in sequence :)
					core:is-fn-seq($_("args"))
				else if($_ instance of xs:string and matches($_,"^\.$|^\$$")) then
					$_
				else
					()
			})
		)
};

declare function core:process-args($frame,$args){
	if($frame instance of xs:string) then
		"n.processArgs($frame,$args)"
	else
		let $name := $frame("$caller")
		let $is-defn := $name = ("core:define-private#6","core:define#6")
		let $is-anon := $name eq "core:function#4"
		let $is-typegen := matches($name,"^core:(typegen|" || string-join(map:keys($core:typemap),"|") || ")")
		return
			a:fold-left-at($args,[],function($pre,$arg,$at){
				if($arg instance of array(item()?)) then
					let $is-params := ($is-defn and $at = 4) or ($is-anon and $at = 1)
					let $is-body := ($is-defn and $at = 6) or ($is-anon and $at = 3)
					let $tco := if($is-defn) then exists(array:flatten(core:detect-tc($arg,$args(2)))) else false()
					let $arg :=
						if($is-defn and $tco) then
							core:tco($arg,(),$args(2),$args(5))
						else
							$arg
					let $fn-seq := core:is-fn-seq($arg)
					let $is-fn-seq := count($fn-seq) > 0
					return
						array:append($pre,
							if($is-params) then
								$arg
							else if($is-fn-seq = false() and $is-body = false()) then
								a:for-each-at($arg,function($_,$at){
									if($_ instance of array(item()?)) then
										core:process-tree($_, $frame)
									else
										core:process-value($_,map:put($frame,"$at",$at))
								})
							else
								let $ret := core:process-tree($arg, $frame, $is-body and $is-fn-seq,"",$at,if($is-body and not($tco)) then $pre($at - 1) else ())
								return if($fn-seq = ".") then concat("function($_0) { return ",$ret,";}") else if($is-fn-seq) then $ret else $ret
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
						core:serialize($arg,$frame))
				else if(($is-defn or $is-typegen) and $at eq 2) then
					array:append($pre,$arg)
				else if(matches($arg,"^_[" || $raddle:suffix || "]?$")) then
					array:append($pre,replace($arg,"^_","_" || $frame("$at")))
				else
					array:append($pre,core:serialize($arg,$frame))
			})
};

declare function core:native($op,$a){
	concat("n.",core:cc($op),"(",$a,")")
};

declare function core:native($op,$a,$b){
	concat("n.",core:cc($op),"(",$a,",",$b,")")
};

declare function core:array($seq) {
	concat("n.array(",$seq,")")
};

declare function core:map($keytype,$valtype,$seq) {
	core:map($seq)
};

declare function core:map($seq) {
	concat("n.map(",$seq,")")
};

declare function core:transpile($value,$frame) {
	let $occ := a:fold-left($value,map{},function($pre,$cur){
		if($cur("name") eq "core:define") then
			let $name := $cur("args")(2)
			return map:put($pre,$name,
				if(map:contains($pre,$name)) then
					array:append($pre($name),array:size($cur("args")(4)))
				else
					[array:size($cur("args")(4))]
			)
		else
			$pre
	})
	let $value := a:fold-left($value,[],function($pre,$cur){
		if($cur("name") eq "core:define") then
			let $name := $cur("args")(2)
			let $args := $cur("args")(4)
			let $s := array:size($args)
			let $t := array:size($occ($name))
			let $pre := array:append($pre,
				if($t > 1) then
					map { "name": "core:define-private", "args": a:put($cur("args"),2,concat($name,"_",$s)), "suffix": "" }
				else
					$cur)
			return
				if($t > 1 and $s = $occ($name)($t)) then
					let $rdl := concat("core:define($,",$name,",(),(core:item($,a...)),core:item(),(",
						"(core:integer($,s,array:size($a)),",
						a:fold-left($occ($name),"",function($p,$_){
							concat($p,"core:iff(core:eq($s,",$_,"),apply(",$name,"_",$_,"#",$_,",$a),")
						}),"()",string-join((1 to $t) ! ")"),")))")
					return array:append($pre,raddle:parse($rdl,$frame)(1))
				else
					$pre
		else
			array:append($pre,$cur)
	})
	return core:process-tree($value,$frame,true())
};

declare function core:process-tree($value,$frame) {
	core:process-tree($value,$frame,false())
};

declare function core:process-tree($value,$frame,$top) {
	core:process-tree($value,$frame,$top,"",1)
};

declare function core:process-tree($tree,$frame,$top,$ret,$at) {
	core:process-tree($tree,$frame,$top,$ret,$at,())
};

declare function core:process-tree($tree,$frame,$top,$ret,$at,$seqtype){
	(: TODO mirror n:eval :)
	(: TODO cleanup into process-args :)
	if(array:size($tree) > 0) then
		let $frame := map:put($frame,"$at",$at)
		let $head := array:head($tree)
		let $frame := if($head instance of map(xs:string,item()?) and $head("name") eq "core:module") then map:put($frame,"$prefix",$head("args")(2)) else $frame
		let $val := core:process-value($head,$frame)
		let $is-body := ($frame("$caller") = ("core:define#6","core:define-private#6")) or ($frame("$caller") = "core:function#4")
		let $is-seq := $val instance of array(item()?)
		let $val :=
			if($is-seq) then
(:				if($top) then:)
					let $s := array:size($val)
					(: assume this is a let-return seq :)
					return
						concat("(",a:fold-left-at($val,"",function($pre,$cur,$at){
							concat($pre,
								if($seqtype and $at eq $s) then
									concat(",&#10;&#13;n.stop($,",substring($seqtype,1,string-length($seqtype) - 1),$cur,"))")
								else
									concat(
										if($at>1) then
											",&#10;&#13;"
										else
											"",
										$cur
									)
							)
						}),")")
(:				else:)
(:					let $n := console:log(($frame("$caller")," || ",$val)) return:)
(:					core:serialize($val,$frame):)
			else
				(: if top in this case, expect exports! :)
				if($top eq false() and $is-body) then
					if($seqtype) then
						concat("n.stop($,",substring($seqtype,1,string-length($seqtype) - 1),$val,"))")
					else
						$val
				else
					$val
		let $ret := concat($ret,if($ret ne "" and $at > 1 and $is-body = false()) then if($top) then "&#10;&#13;" else ",&#10;&#13;" else "",$val)
		return core:process-tree(array:tail($tree),$frame,$top,$ret,$at + 1)
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

declare function core:stop($seqtype,$val){
	concat("n.stop($,",substring($seqtype,1,string-length($seqtype) - 1),$val,"))")
};


declare function core:cont($val){
	(: TODO actual params :)
	concat("n.cont($,",substring($val,7,string-length($val)-1),")")
};

declare function core:find-tc($a,$name,$pos){
	for $x at $i in array:flatten($a) return
		if($x instance of map(xs:string,item()?)) then
			if($x("name") eq $name) then
				if($pos) then $pos else $i
			else
				core:find-tc($x("args"),$name,$i)
		else
			()
};

declare function core:detect-tc($a,$name){
	a:for-each($a,function($n){
		let $ismap := $n instance of map(xs:string,item()?)
		return
			if($ismap and $n("name") eq "core:iff") then
				core:find-tc($n("args"),$name,0)
			else if($n instance of array(item()?)) then
				core:detect-tc($n,$name)
			else
				if($ismap) then
					core:detect-tc($n("args"),$name)
				else
					()
	 })
};


declare function core:tco($a,$tc,$name,$type){
	a:for-each-at($a,function($n,$at){
		let $ismap := $n instance of map(xs:string,item()?)
		return
			if($ismap and $n("name") eq "core:iff") then
				(: expect 3 args :)
				let $args := $n("args")
				let $self := core:find-tc($args,$name,0)
				return
					map:put($n,"args",core:tco($args,$self,$name,$type))
			else if($n instance of array(item()?)) then
				core:tco($n,$tc,$name,$type)
			else
				if($ismap and $name and $n("name") eq $name) then
					map:put(map:put($n,"args",[$n("args")]),"name","core:cont")
				else if($at > 1 and $at ne $tc) then
					map {
						"name": "core:stop",
						"args": [$type,$n]
					}
				else
					$n
	 })
};

declare function core:process-value($value,$frame){
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
				let $is-defn := $local = ("define","define-private")
				let $is-fn := ($is-defn and $s eq 6) or ($local eq "function" and $s eq 4)
				let $frame := map:put($frame,"$caller",concat($name,"#",$s))
				(:
				let $hoisted :=
					if($is-fn) then
						let $i := if($local = ("define","define-private")) then 6 else 3
						return core:hoist($args($i))
					else
						()
				:)
				let $args := core:process-args($frame,$args)
				(:
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
								concat("var ",string-join(($hoisted ! core:cc(.)),","),";&#10;&#13;",$args($i))
							else
								$args($i)
						return a:put($args,$i,$body)
					else
						$args
				:)
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
							concat("n.seq(",string-join(array:flatten($_),","),")")
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
				let $n := if(empty($fn)) then console:log(($name,"#",$s)) else ()
				return apply($fn,$args)
			else if($name eq "") then
				core:process-args(map:put($frame,"$caller",""),$args)
			else
				let $frame := map:put($frame,"$caller",concat($name,"#",$s))
				let $args := core:process-args($frame,$args)
				(: FIXME add check for seq calls :)
				let $ret :=
					a:fold-left-at($args,"",function($pre,$cur,$at){
						let $is-seq := $cur instance of array(item()?)
						return concat($pre,
							if($at>1) then "," else "",
							if($is-seq) then
								concat("n.seq(",string-join(array:flatten($cur),","),")")
							else
								$cur
						)
					})
				return
					(: FIXME add default fn ns prefix :)
					if(matches($name,"^(\$.*)$|^([^#]+#[0-9]+)$")) then
						concat("n.call(",core:convert($name,$frame),",",$ret,")")
					else
						concat(core:function-name($name,$s,$frame("$prefix"),"fn"),"(",$ret,")")
	else
		if(matches($value,"^_[" || $raddle:suffix || "]?$")) then
			replace($value,"^_","\$_" || $frame("$at"))
		else
			core:serialize($value,$frame)
};

declare %private function core:is-current-module($frame,$name){
	"n.isCurrentModule($frame,$name)"
};

declare function core:convert($string,$frame){
	if(matches($string,"^n\.call")) then
		$string
	else if(matches($string,"^(\$.*)$|^([^#]+#[0-9]+)$")) then
		let $parts := tokenize(core:cc(replace($string,"#\p{N}+$","")),":")
		return
			if(count($parts) eq 1) then
				concat("n.fetch($,&quot;",replace($parts[1],"\$",""),"&quot;)")
			else if(matches($parts[1],concat("^\$?",$frame("$prefix")))) then
				replace($parts[last()],"\$","")
			else
				concat(replace($parts[1],"\$",""),".",$parts[2])
	else if(matches($string,"^(&quot;[^&quot;]*&quot;)$")) then
		concat("n.string(",replace($string,"\\","\\\\"),")")
	else if(map:contains($core:auto-converted,$string)) then
		$core:auto-converted($string)
	else
		if(string(number($string)) = "NaN") then
			concat("n.string(&quot;",replace($string,"\\","\\\\"),"&quot;)")
		else if(matches($string,"\.")) then
			concat("n.decimal(",$string,")")
		else
			concat("n.integer(",$string,")")
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
	"n.resolveFunction($frame,$name)"
};

declare function core:resolve-function($frame,$name,$self){
	"n.resolveFunction($frame,$name,$self)"
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
		"n.import($frame,$prefix,$ns)"
	else
		concat("import * as ", core:clip($prefix), " from ", $ns)
};

declare function core:import($frame,$prefix,$ns,$loc) {
	if($frame instance of xs:string) then
		"n.import($frame,$prefix,$ns)"
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
			"",
			core:cc($prefix),
			if($prefix) then "." else "",
			core:cc($p[last()])
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
	concat("export const ",$name," = ",$body,";")
};

declare function core:define-private($frame,$name,$def,$args,$type,$body) {
	core:define($frame,$name,$def,$args,$type,$body,true())
};

declare function core:define($frame,$name,$def,$args,$type,$body) {
	core:define($frame,$name,$def,$args,$type,$body,false())
};

declare function core:define($frame,$name,$def,$args,$type,$body,$private) {
	let $params := a:for-each($args,function($_){
		if($_ instance of map(xs:string,item()?)) then
			let $a := array:tail($_("args"))
			let $a := array:insert-before($a,2,replace($_("name"),"core:",""))
			let $a := array:insert-before($a,2,())
			return $a
		else if($_ instance of xs:string) then
			[
				replace($_,"^\$",""),
				(),
				"item"
			]
		else
			[]
	})
	let $parts := tokenize(core:clip($name),":")
	let $fname := core:cc($parts[last()])
	return concat(if($private) then "" else "export ","function ",$fname,"() {&#10;&#13;return n.initialize(arguments,",local:serialize($params),
		",function($){&#10;&#13;return ",$body,";});&#10;&#13;}")
};

declare function core:describe($frame,$name,$def,$args,$type){
	core:map([])
};

declare function core:function($args,$type,$body) {
	let $n := console:log($args)
	let $params := a:for-each($args,function($_){
		if($_ instance of map(xs:string,item()?)) then
			let $a := array:tail($_("args"))
			let $a := array:insert-before($a,2,replace($_("name"),"core:",""))
			let $a := array:insert-before($a,2,())
			return $a
		else if($_ instance of xs:string) then
			[
				replace($_,"^\$",""),
				(),
				"item"
			]
		else
			[]
	})
	return concat("function() {&#10;&#13;return n.initialize(arguments,",local:serialize($params),
		",function($){&#10;&#13;return ",$body,";});&#10;&#13;}")
};

declare function core:cap($str){
	let $cp := string-to-codepoints($str)
	return codepoints-to-string((string-to-codepoints(upper-case(codepoints-to-string(head($cp)))),tail($cp)))
};


declare function core:iff($a,$b,$c){
	concat("n.iff($,",$a,",&#10;&#13;function($){&#10;&#13;return ",$b,";&#10;&#13;},&#10;&#13;function($){&#10;&#13;return ",$c,";&#10;&#13;})")
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

declare function core:typegen1($type,$name,$seq) {
	concat("n.",$type,"(",$name,",",$seq,")")
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

declare function core:var-name($name) {
	concat("&quot;",replace(core:cc(core:clip($name)),"\$",""),"&quot;")
};

declare function core:typegen($type,$val) {
	"n." || $type || "(" || $val || ")"
};

declare function core:clip($name){
	if(matches($name,"^&quot;.*&quot;$")) then raddle:clip-string($name) else $name
};

declare function core:param-name($name) {
	replace(concat("$",replace(core:cc(core:clip($name)),"\$","")),"^([^\.]*)(\.{3})$","$2 $1")
};

declare function core:typegen($type,$frame,$name){
	core:param-name($name)
};

declare function core:typegen($type,$frame,$name,$val){
	core:typegen($type,$frame,$name,$val,"")
};

declare function core:typegen($type,$frame,$name,$val,$suffix) {
	let $n := console:log($name) return
	if($val) then
		concat("n.put($,",core:var-name($name),",n.",$type,"(",$val,"))")
	else
		core:param-name($name) || " /* " || $type || $suffix || " */"
};
