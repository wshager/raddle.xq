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

declare function core:is-caller($args) {
	a:fold-left($args,false(),function($pre,$arg) {
		$pre or ($arg instance of map(xs:string,item()?) and $arg("name") eq "")
	})
};

declare function core:process-args($frame,$args){
	if($frame instance of xs:string) then
		"n.processArgs($frame,$args)"
	else
		let $name := $frame("$caller")
		let $is-init := matches($name,"^core:init")
		let $is-defn := $name = ("core:define-private#6","core:define#6")
		let $is-anon := $name eq "core:function#4"
		let $is-typegen := matches($name,"^core:(typegen|" || string-join(map:keys($core:typemap),"|") || ")")
		return
			a:fold-left-at($args,[],function($pre,$arg,$at){
				if($arg instance of array(item()?)) then
					let $is-params := ($is-defn and $at = 4) or ($is-anon and $at = 1)
					let $is-body := ($is-defn and $at = 6) or ($is-anon and $at = 3)
					let $tco := if($is-defn) then core:detect-tc($frame("$tree"),$arg,$args(2),$args(2)) else ()
                    let $nu := if($is-defn and $args(2) eq "xqc:body-op") then console:log($tco) else ()
					let $arg :=
						if($is-defn and $tco) then
							core:tco($arg,$tco,$args(5))
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
(:					let $nu := if(array:size($args) > $at and core:is-caller(array:subarray($args,$at + 1))) then console:log($arg) else ():)
					let $s := array:size($pre) return
					if($arg("name") ne "" and array:size($args) > $at and core:is-caller(array:subarray($args,$at + 1))) then
						array:append($pre,map {
							"name": "core:call",
							"args": [$arg("name"),map {
								"name": "",
								"args": $arg("args")
							}]
						})
					else if($arg("name") eq "" and  $s > 1) then
						if($pre($s) instance of map(xs:string,item()?) and $pre($s)("name") eq "core:call") then
							let $cc := $pre($s)
							return a:put($pre,$s,map {
								"name": "core:call",
								"args": [$cc,map {
									"name": "",
									"args": $arg("args")
								}]
							})
						else
							array:append($pre,core:process-value($arg,$frame))
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
				else if((($is-defn or $is-typegen) and $at eq 2) or ($is-init and $at eq 1)) then
				    (: escape proper names :)
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

declare function core:pair($key,$val){
    concat("n.pair(",$key,",",$val,")")
};

declare function core:map($seq) {
	concat("n.map(",$seq,")")
};

declare function core:map() {
	concat("n.map()")
};

declare function core:_init($name,$a,$private){
    let $parts := tokenize(core:clip($name),":")
	let $fname := core:cc($parts[last()])
	return
    concat(if($private) then "" else "export ",
    "function ",$fname,"(... a) {
	var l = a.length,
        $ = n.frame(a);",
    string-join($a,"&#13;"),"
    return n.error(&quot;err:XPST0017&quot;,&quot;Function ",$fname," called with &quot;+l+&quot; arguments doesn't match any of the known signatures.&quot;);
}")
};

declare function core:init($name,$a){
    core:_init($name,$a,false())
};

declare function core:init($name,$a,$b){
    core:_init($name,($a,$b),false())
};

declare function core:init($name,$a,$b,$c){
    core:_init($name,($a,$b,$c),false())
};

declare function core:transpile($value,$frame) {
	let $occ := a:fold-left-at($value,map{},function($pre,$cur,$i){
		if($cur("name") eq "core:define") then
			let $name := $cur("args")(2)
			return map:put($pre,$name,
				if(map:contains($pre,$name)) then
					array:append($pre($name),$i)
				else
					[$i]
			)
		else
			$pre
	})
	let $frame := map:put($frame,"$tree",$value)
	let $value := a:fold-left-at($value,[],function($pre,$cur,$i){
		if($cur("name") eq "core:define") then
			let $name := $cur("args")(2)
			let $index := $occ($name)(1)
			return
			    if($index eq $i) then
			        array:append($pre, map { "name": "core:init", "args": [$name,$cur], "suffix": ""})
				else
				    a:put($pre,$index, map { "name": "core:init", "args": array:append($pre($index)("args"),$cur), "suffix": ""})
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
									concat(",&#10;&#13;",substring($seqtype,1,string-length($seqtype) - 1),$cur,")")
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
						concat(substring($seqtype,1,string-length($seqtype) - 1),$val,")")
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
	concat("$.stop(",substring($seqtype,1,string-length($seqtype) - 1),$val,"))")
};


declare function core:rec($a){
	(: it's dirty but... it's better :)
(:	concat("$.rec(",replace($a,"^([^\(]*)\(","$1,")):)
    $a
};


declare function core:resolve-module($tree,$name){
    if($tree instance of map(xs:string,item()?)) then
        if($tree("name") eq "core:define" and $tree("args")(2) eq $name) then
            $tree
        else
            core:resolve-module($tree("args"),$name)
    else
        if($tree instance of array(item()?)) then
            array:flatten(array:for-each($tree,function($arg){
                core:resolve-module($arg,$name)
            }))
        else
            ()
};

declare function core:check-deep($tree,$resolve,$name){
    (: only look in current module :)
    if(matches($resolve,replace($name,"^([^:]+).*","^$1"))) then
        (: only look one level deep :)
        core:find-tc([],array { core:resolve-module($tree,$resolve) },$name,$resolve)
    else
        ()
};

declare function core:find-tc($tree,$a,$name,$lastname){
	if($a instance of array(item()?)) then
		a:fold-left($a,(),function($pre,$x){
			if($x instance of map(xs:string,item()?)) then
				if($x("name") eq $name) then
					$lastname
				else
					if($pre) then $pre else
					    let $shallow := core:find-tc($tree,$x("args"),$name,$lastname)
					    return if($shallow) then
					        $shallow
					    else
					        if($name eq "xqc:body-op") then
					            core:check-deep($tree,$x("name"),$name)
					        else
					            ()
			else if($x instance of array(item()?)) then
			    if($pre) then $pre else core:find-tc($tree,$x,$name,$lastname)
			else
				$pre
		})
	else if($a instance of map(xs:string,item()?)) then
		if($a("name") eq $name) then
			$lastname
		else
(:		    let $nu := if($name eq "xqc:body") then console:log($a) else () return:)
			core:find-tc($tree,$a("args"),$name,if($a("name") ne "core:iff") then $a("name") else $name)
	else
		()
};

declare function core:detect-tc($tree,$a,$name,$lastname){
	a:fold-left($a,(),function($pre,$n){
		let $ismap := $n instance of map(xs:string,item()?)
		return
			if($ismap and $n("name") eq "core:iff") then
				if($pre) then $pre else core:find-tc($tree,$n("args"),$name,$lastname)
			else if($n instance of array(item()?)) then
				if($pre) then $pre else core:detect-tc($tree,$n,$name,$lastname)
			else
				if($ismap) then
					if($pre) then $pre else core:detect-tc($tree,$n("args"),$name,$lastname)
				else
					$pre
	 })
};

declare function core:tco($a,$name,$type){
	core:tco($a,$name,$type,())
};

declare function core:tco($a,$name,$type,$stop){
	a:for-each-at($a,function($n,$at){
		if($n instance of map(xs:string,item()?)) then
			if($n("name") eq $name) then
				map {
				    "name": "core:rec",
				    "args": [$n]
				}
			else if($n("name") eq "core:iff") then
				(: expect 3 args :)
				let $stopped := $stop
				let $args := $n("args")
				let $first := core:find-tc($a,$args(2),$name,$name)
				let $second := if(array:size($args) > 2) then core:find-tc($a,$args(3),$name,$name) else ()
(:				let $nu := if($name eq "xqc:body-op") then console:log(($name,",",$first,",",$second)) else ():)
				let $stop :=
					if($first or $second) then
						if($first and $second) then
							()
						else if($first) then 3 else 2
					else
						()
				let $n :=
					map:put($n,"args",core:tco($args,$name,$type,$stop))
				return
(:					if($stopped eq $at) then:)
(:						map {:)
(:							"name": "core:stop",:)
(:							"args": [$type,$n]:)
(:						}:)
(:					else:)
						$n
			else
				let $n := map:put($n,"args", core:tco($n("args"),$name,$type))
				return
(:				    if($stop eq $at) then:)
(:						map {:)
(:							"name": "core:stop",:)
(:							"args": [$type,$n]:)
(:						}:)
(:					else:)
						$n
		else if($n instance of array(item()?)) then
			if($stop eq $at) then
				if(array:size($n) > 0 and $n(1) instance of map(xs:string,item()?)) then
					core:tco($n,$name,$type,array:size($n))
				else $n
(:					map {:)
(:						"name": "core:stop",:)
(:						"args": [$type,$n]:)
(:					}:)
			else
				core:tco($n,$name,$type)
		else
(:			if($stop eq $at) then:)
(:				map {:)
(:					"name": "core:stop",:)
(:					"args": [$type,$n]:)
(:				}:)
(:			else:)
				$n
 })
};

declare function core:call($a,$b) {
	concat("n.call(",$a,",",$b,")")
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
						if($_ instance of array(item()?) and not($is-fn)) then
							concat("n.seq(",string-join(array:flatten($_),","),")")
						else if($_ instance of map(xs:string,item()?) and $_("name") eq "core:call") then
							core:process-value($_,$frame)
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
				let $n := if(empty($fn)) then console:log(($name,",",$args)) else ()
				return apply($fn,$args)
			else if($name eq "") then
				let $args := core:process-args(map:put($frame,"$caller",""),$args)
				return
					a:for-each($args,function($_){
						if($_ instance of array(item()?)) then
							concat("n.seq(",string-join(array:flatten($_),","),")")
						else if($_ instance of map(xs:string,item()?) and $_("name") eq "core:call") then
							core:process-value($_,$frame)
						else
							$_
					})
			else
				let $frame := map:put($frame,"$caller",concat($name,"#",$s))
				let $args := core:process-args($frame,$args)
				(: FIXME add check for seq calls :)
				let $ret :=
					a:fold-left-at($args,"",function($pre,$cur,$at){
						concat($pre,
							if($at>1) then "," else "",
							if($cur instance of array(item()?)) then
								concat("n.seq(",string-join(array:flatten($cur),","),")")
							else if($cur instance of map(xs:string,item()?)) then
								core:process-value($cur,$frame)
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
	else if($value instance of array(item()?)) then
		concat("n.seq(",core:process-tree($value,$frame),")")
	else if(matches($value,"^_[" || $raddle:suffix || "]?$")) then
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
				concat("$.get(&quot;",replace($parts[1],"\$",""),"&quot;)")
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

declare function core:namespace($frame,$prefix,$ns) {
	if($frame instance of xs:string) then
		"n.namespace($frame,$prefix,$ns)"
	else
		concat("//declare namespace ", core:clip($prefix), " = ", $ns)
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
	(:
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
	:)
	let $params :=
	    array:flatten(a:for-each($args,function($_){
	        if($_ instance of map(xs:string,item()?)) then
    			concat(
    			    replace($_("name"),"core:","\$."),
    			    "(",
    			    string-join(array:flatten(array:tail($_("args")))!concat("&quot;",.,"&quot;"),","),
    			    ")")
    		else if($_ instance of xs:string) then
				concat("$.item(&quot;",replace($_,"^\$",""),"&quot;)")
    		else
    			()
	    }))
	let $parts := tokenize(core:clip($name),":")
	let $fname := core:cc($parts[last()])
	return concat("
    if(l==",count($params),"){
        $.init(",string-join($params,","),");
        return ",$body,";
    }")
};

declare function core:describe($frame,$name,$def,$args,$type){
	core:map()
};

declare function core:function($args,$type,$body) {
	let $params :=
	    array:flatten(a:for-each($args,function($_){
	        if($_ instance of map(xs:string,item()?)) then
    			concat(
    			    replace($_("name"),"core:","\$."),
    			    "(",
    			    string-join(array:flatten(array:tail($_("args")))!concat("&quot;",.,"&quot;"),","),
    			    ")")
    		else if($_ instance of xs:string) then
				concat("$.item(&quot;",replace($_,"^\$",""),"&quot;)")
    		else
    			()
	    }))
	return concat("function(...a){
    var l = a.length,
        $ = n.frame(a);
    if(l==",count($params),"){
        return $.func(",string-join($params,","),",$ => ",$body,");
    }
    return n.error(&quot;err:XPST0017&quot;,&quot;Anonymous function called with &quot;+l+&quot; arguments doesn't match any of the known signatures.&quot;);
}")
};

declare function core:cap($str){
	let $cp := string-to-codepoints($str)
	return codepoints-to-string((string-to-codepoints(upper-case(codepoints-to-string(head($cp)))),tail($cp)))
};


declare function core:iff($a,$b,$c){
    concat("$.test(",$a,") ?&#10;&#13; (",$b,") :&#10;&#13; (",$c,")")
(:	concat("$.if(",$a,")&#10;&#13;.then($ => { return ",$b,"})&#10;&#13;.else($ => { return ",$c,"})"):)
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
	if($val) then
		concat("$.",$type,"(",core:var-name($name),",",$val,")")
	else
		core:param-name($name) || " /* " || $type || $suffix || " */"
};
