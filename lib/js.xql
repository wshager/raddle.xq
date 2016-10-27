xquery version "3.1";

module namespace core="http://raddle.org/javascript";

import module namespace rdl="http://raddle.org/raddle" at "../content/raddle.xql";
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
	"anon": 2,
	"array": 1,
	"element": 1,
	"attribute": 1
};

declare variable $core:native-ops := (
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
	"true" : "true()",
	"false" : "false()",
	"null" : "()",
	"undefined" : "()",
	"Infinity" : "1 div 0e0",
	"-Infinity" : "-1 div 0e0"
};

declare function core:xq-version($frame,$version){
	"/* xquery version " || $version || " */"
};

declare %private function core:is-fn-seq($value) {
	if($value instance of xs:string) then
	    concat("isFnSeq(",$value,")")
	else
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
	if($args instance of xs:string) then
	    concat("isCaller(",$args,")")
	else
	    a:fold-left($args,false(),function($pre,$arg) {
    		$pre or ($arg instance of map(xs:string,item()?) and $arg("name") eq "")
    	})
};

declare function core:process-args($frame,$args){
	if($frame instance of xs:string) then
	    concat("processArgs(",$frame,",",$args,")")
	else
		let $name := $frame("$caller")
		let $is-init := matches($name,"^core:init")
		let $is-defn := $name = ("core:define-private#6","core:define#6")
		let $is-anon := $name eq "core:anon#4"
		let $is-typegen := matches($name,"^core:(typegen|" || string-join(map:keys($core:typemap),"|") || ")")
		return
			a:fold-left-at($args,[],function($pre,$arg,$at){
				if($arg instance of array(item()?)) then
					let $is-params := ($is-defn and $at = 4) or ($is-anon and $at = 1)
					let $is-body := ($is-defn and $at = 6) or ($is-anon and $at = 3)
(:					let $tco := if($is-defn) then core:detect-tc($frame("$tree"),$arg,$args(2),$args(2)) else ():)
(:                    let $nu := if($is-defn and $args(2) eq "xqc:body-op") then console:log($tco) else ():)
(:					let $arg :=:)
(:						if($is-defn and $tco) then:)
(:							core:tco($arg,$tco,$args(5)):)
(:						else:)
(:							$arg:)
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
								let $ret := core:process-tree($arg, $frame, $is-body and $is-fn-seq,"",$at,if($is-body (:and not($tco):)) then $pre($at - 1) else ())
								return if($fn-seq = ".") then concat("function($_0) { return ",$ret,";}") else if($is-fn-seq) then $ret else $ret
						)
				else if($arg instance of map(xs:string,item()?)) then
					let $s := array:size($pre)
					return
					    if($arg("name") ne "" and array:size($args) > $at and core:is-caller(array:subarray($args,$at + 1))) then
    						array:append($pre,map {
    							"name": "core:call",
    							"args": [$arg("name"),map {
    								"name": "",
    								"args": $arg("args")
    							}]
    						})
    					else if($arg("name") eq "" and  $s > 1) then
    					    let $last := $pre($s)
    					    return
        						if($last instance of map(xs:string,item()?) and $last("name") eq "core:call") then
        							a:put($pre,$s,map {
        								"name": "core:call",
        								"args": [$last,map {
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
				else if(matches($arg,"^\$[" || $rdl:ncname || "]+$")) then
					array:append($pre,if(matches($arg,"^\$\p{N}")) then
						replace($arg,"^\$","\$_")
					else
						core:serialize([$arg,$frame]))
				else if((($is-defn or $is-typegen) and $at eq 2) or ($is-init and $at eq 1)) then
				    (: escape proper names :)
					array:append($pre,$arg)
				else if(matches($arg,"^_[" || $rdl:suffix || "]?$")) then
					array:append($pre,replace($arg,"^_","_" || $frame("$at")))
				else
					array:append($pre,core:serialize([$arg,$frame]))
			})
};

declare function core:native($op,$a){
	concat("n.",rdl:camel-case($op),"(",$a,")")
};

declare function core:native($op,$a,$b){
	concat("n.",rdl:camel-case($op),"(",$a,",",$b,")")
};

declare function core:pair($key,$val){
    concat("n.pair(",$key,",",$val,")")
};

declare function core:_init($name,$a){
    if($a instance of xs:string) then
        concat("_init(",$name,",",$a,")")
    else
    (: private functions not possible now :)
    let $private := false()
    let $parts := tokenize(rdl:clip($name),":")
	let $fname := rdl:camel-case($parts[last()])
	return
    concat(
        if($private) then "" else "export ",
        "function ",$fname,"(...$_a) {&#13;&#9;",
	    "var $_l = $_a.length,&#13;&#9;&#9;",
        "$ = n.frame($_a);&#13;&#9;",
        string-join(array:flatten($a),"&#13;"),"&#13;&#9;",
        "return n.error(",$fname,",$_l);&#13;}"
    )
};

declare function core:init($name,$a){
    core:_init($name,[$a])
};

declare function core:init($name,$a,$b){
    core:_init($name,[$a,$b])
};

declare function core:init($name,$a,$b,$c){
    core:_init($name,[$a,$b,$c])
};


declare function core:init($name,$a,$b,$c,$d){
    core:_init($name,[$a,$b,$c,$d])
};

declare function core:init($name,$a,$b,$c,$d,$e){
    core:_init($name,[$a,$b,$c,$d,$e])
};


declare function core:init($name,$a,$b,$c,$d,$e,$f){
    core:_init($name,[$a,$b,$c,$d,$e,$f])
};

declare function core:transpile($value,$frame) {
	let $frame := map:put($frame,"$tree",$value)
	let $distinct := a:fold-left-at($value,map{},function($pre,$cur,$i){
		if($cur("name") = ("core:define","core:define-private")) then
			let $name := $cur("args")(2)
			return
			    if(map:contains($pre,$name)) then
			        $pre
			    else
			        map:put($pre,$name,$i)
		else
			$pre
	})
	let $value := array:filter(a:fold-left-at($value,[],function($pre,$cur,$i){
		if($cur("name") = ("core:define","core:define-private")) then
			let $name := $cur("args")(2)
			let $index := $distinct($name)
			return
			    if($index eq $i) then
			        array:append($pre, map { "name": "core:init", "args": [$name,$cur], "suffix": ""})
				else
				    let $last := $pre($index)
				    return a:put(array:append($pre,()),$index, map { "name": "core:init", "args": array:append($last("args"),$cur), "suffix": ""})
		else
			array:append($pre,$cur)
	}),function($a){
	    exists($a)
	})
	return core:process-tree($value,$frame,true())
};

declare function core:process-tree($tree,$frame) {
    if($tree instance of xs:string) then
	    concat("processTree(",$tree,",",$frame,")")
	else
	    core:process-tree($tree,$frame,false())
};

declare function core:process-tree($tree,$frame,$top) {
    if($tree instance of xs:string) then
	    concat("processTree(",$tree,",",$frame,",",$top,")")
	else
	    core:process-tree($tree,$frame,$top,"",1,())
};

declare function core:process-tree($tree,$frame,$top,$ret,$at) {
    if($tree instance of xs:string) then
	    concat("processTree(",$tree,",",$frame,",",$top,",",$ret,",",$at,")")
	else
	    core:process-tree($tree,$frame,$top,$ret,$at,())
};

declare function core:process-tree($tree,$frame,$top,$ret,$at,$seqtype){
	(: TODO mirror n:eval :)
	(: TODO cleanup into process-args :)
    if($tree instance of xs:string) then
	    concat("processTree(",$tree,",",$frame,",",$top,",",$ret,",",$at,",",$seqtype,")")
	else if(array:size($tree) > 0) then
		let $frame := map:put($frame,"$at",$at)
		let $head := array:head($tree)
		let $frame := if($head instance of map(xs:string,item()?) and $head("name") eq "core:module") then map:put($frame,"$prefix",$head("args")(2)) else $frame
		let $val := core:process-value($head,$frame)
		let $is-body := ($frame("$caller") = ("core:define#6","core:define-private#6")) or ($frame("$caller") = "core:anon#4")
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
									concat(",&#13;",substring($seqtype,1,string-length($seqtype) - 1),$cur,")")
								else
									concat(
										if($at>1) then
											",&#13;"
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
		return core:process-tree(array:tail($tree),$frame,$top,$ret,$at + 1,())
	else if($at = 1) then
		"n.seq()"
	else
		$ret
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


declare function core:call($a,$b) {
	concat("n.call(",$a,",",$b,")")
};

declare function core:process-value($value,$frame){
    if($frame instance of xs:string) then
        concat("processValue(",$value,",",$frame,")")
	else if($value instance of map(xs:string,item()?)) then
		let $name := $value("name")
		let $args := $value("args")
		let $s := if(map:contains($value,"args")) then array:size($args) else 0
		return
		    if(map:contains($value,"$tree")) then
                ""
			else if(matches($name,"^core:[" || $rdl:ncname || "]+$")) then
				let $local := replace($name,"^core:","")
				let $is-type := $local = map:keys($core:typemap)
				let $is-native := $core:native-ops = $local
				let $s := if($is-type or $is-native) then $s + 1 else $s
				let $is-defn := $local = ("define","define-private")
				let $is-fn := ($is-defn and $s eq 6) or ($local eq "anon" and $s eq 4)
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
								concat("var ",string-join(($hoisted ! rdl:camel-case(.)),","),";&#10;&#13;",$args($i))
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
				let $n := if(empty($fn)) then console:log(($name,"#",array:size($args),",",$args)) else ()
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
						concat(core:anon-name($frame,$name,$s,"fn"),"(",$ret,")")
	else if($value instance of array(item()?)) then
		concat("n.seq(",core:process-tree($value,$frame),")")
	else if(matches($value,"^_[" || $rdl:suffix || "]?$")) then
		replace($value,"^_","\$_" || $frame("$at"))
	else
		core:serialize([$value,$frame])
};

declare %private function core:is-current-module($frame,$name){
	concat("isCurrentModule(",$frame,",",$name,")")
};

declare function core:convert($string,$frame){
    if($frame instance of xs:string) then
        concat("convert(",$string,",",$frame,")")
	else if(matches($string,"^n\.call")) then
		$string
	else if(matches($string,"^(\$.*)$|^([^#]+#[0-9]+)$")) then
		let $parts := tokenize(rdl:camel-case(replace($string,"#\p{N}+$","")),":")
		return
			if(count($parts) eq 1) then
				concat("$.get(&quot;",replace($parts,"^\$",""),"&quot;)")
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

declare function core:serialize($args){
    if($args instance of xs:string) then
        concat("serialize(",$args,")")
    else
        let $value := $args(1)
        let $params := $args(2)
        return
        	if($value instance of map(xs:string, item()?)) then
        		concat($value("name"),
        		    if(map:contains($value,"args")) then
        		        core:serialize([$value("args"),$params])
        		    else
        		        "()"
        		    ,
        		    if(map:contains($value,"suffix")) then $value("suffix") else ""
        	    )
        	else if($value instance of array(item()?)) then
        		concat("(",
        		    a:fold-left-at($value,"",function($pre,$cur,$at){
        			    let $is-seq := ($cur instance of map(xs:string, item()?) and $cur("name") eq "")
        			    return concat($pre,
            				if($at>1 and $is-seq=false()) then "," else "",
            				core:serialize([$cur,$params])
            			)
        		    }),")")
        	else
        		core:convert($value,$params)
};

declare function core:resolve-function($frame,$name){
	concat("resolveFunction(",$frame,",",$name,")")
};

declare function core:resolve-function($frame,$name,$self){
	concat("resolveFunction(",$frame,",",$name,",",$self,")")
};

declare function core:module($frame,$prefix,$ns,$desc) {
	concat("/*module namespace ", rdl:clip($prefix), "=", $ns, ";&#10;&#13;",$desc,"*/")
};

declare function core:namespace($frame,$prefix,$ns) {
	if($frame instance of xs:string) then
		concat("namespace(",$frame,",",$prefix,",",$ns,")")
	else
		concat("//declare namespace ", rdl:clip($prefix), " = ", $ns)
};

declare function core:ximport($frame,$prefix,$ns) {
	if($frame instance of xs:string) then
		concat("ximport(",$frame,",",$prefix,",",$ns,")")
	else
		concat("import * as ", rdl:clip($prefix), " from ", $ns)
};

declare function core:ximport($frame,$prefix,$ns,$loc) {
	if($frame instance of xs:string) then
		concat("ximport(",$frame,",",$prefix,",",$ns,",",$loc,")")
	else
		concat("import * as ", rdl:clip($prefix), " from ", replace($loc,"(\.xql|\.rdl)&quot;$",".js&quot;"), "")
};

declare function core:anon-name($frame,$name,$arity,$default-prefix){
    if($frame instance of xs:string) then
        concat("anonName(",$frame,",",$name,",",$arity,",",$default-prefix,")")
    else
        let $prefix := $frame("$prefix")
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
    			rdl:camel-case($prefix),
    			if($prefix) then "." else "",
    			rdl:camel-case($p[last()])
    		)
};

declare function core:xvar($frame,$name,$def,$body){
	concat("export const ",$name," = ",$body,";")
};


declare function core:define($frame,$name,$def,$args,$type) {
    if($frame instance of xs:string) then
        concat("define(",$frame,",",$name,",",$def,",",$args,",",$type,")")
    else
	    core:define($frame,$name,$def,$args,$type,"")
};

declare function core:define-private($frame,$name,$def,$args,$type,$body) {
    if($frame instance of xs:string) then
        concat("definePrivate(",$frame,",",$name,",",$def,",",$args,",",$type,",",$body,")")
    else
	    core:define($frame,$name,$def,$args,$type,$body,true())
};

declare function core:define($frame,$name,$def,$args,$type,$body) {
    if($frame instance of xs:string) then
        concat("define(",$frame,",",$name,",",$def,",",$args,",",$type,",",$body,")")
    else
	    core:define($frame,$name,$def,$args,$type,$body,false())
};

declare function core:define($frame,$name,$def,$args,$type,$body,$private) {
    if($frame instance of xs:string) then
        concat("define(",$frame,",",$name,",",$def,",",$args,",",$type,",",$body,",",$private,")")
    else
    	let $params :=
    	    array:flatten(a:for-each($args,function($_){
    	        if($_ instance of map(xs:string,item()?)) then
    	            let $args := $_("args")
    	            let $param := $args(2)
        			return concat(
        			    replace($_("name"),"core:","\$."),
        			    "(",
        			    string-join(for-each($param,function($_) { concat("&quot;",$_,"&quot;") }),","),
        			    ")")
        		else if($_ instance of xs:string) then
    				concat("$.item(&quot;",replace($_,"^\$",""),"&quot;)")
        		else
        			()
    	    }))
    	let $parts := tokenize(rdl:clip($name),":")
    	let $fname := rdl:camel-case($parts[last()])
    	return concat(
    	    "&#13;&#9;if($_l==",count($params),"){&#13;&#9;&#9;",
            "$.init(",string-join($params,","),");&#13;&#9;&#9;",
            "return ",$body,";&#13;&#9;}"
        )
};

declare function core:describe($frame,$name,$def,$args,$type){
	"n.map()"
};

declare function core:anon($args,$type,$body) {
    if($args instance of xs:string) then
        concat("anon(",$args,",",$type,",",$body,")")
    else
    	let $params :=
    	    array:flatten(a:for-each($args,function($_){
    	        if($_ instance of map(xs:string,item()?)) then
        			concat(
        			    replace($_("name"),"core:","\$."),
        			    "(",
        			    string-join(for-each(array:flatten(array:tail($_("args"))),function($_) { concat("&quot;",$_,"&quot;")}),","),
        			    ")")
        		else if($_ instance of xs:string) then
    				concat("$.item(&quot;",replace($_,"^\$",""),"&quot;)")
        		else
        			()
    	    }))
    	return concat(
    	    "function(...$_a){&#13;&#9;",
        	"var $_l = $_a.length;&#13;&#9;",
        	"$ = n.frame($,$_a);&#13;",
            "if($_l==",count($params),"){&#13;&#9;",
            "$.init(",string-join($params,","),");&#13;&#9;&#9;",
            "return ",$body,";&#13;    }&#13;&#9;",
            "return n.error($_l);&#13;}"
        )
};



declare function core:iff($a,$b,$c){
    concat("$.test(",$a,") ?&#13; (",$b,") :&#13; (",$c,")")
(:	concat("($ => { if($) {&#13;",$b,"&#13;} else {&#13; ",$c,"&#13;} })(n.test(",$a,"))"):)
};

declare function core:typegen1($type,$seq) {
    concat("n.",$type,"(",$seq,")")
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

declare function core:typegen2($type) {
	$type
};

declare function core:typegen2($type,$keytype,$valtype,$body) {
	if($type eq "map") then
	    concat("n.map(",$body,")")
	else
		core:anon($keytype,$valtype,$body)
};

declare function core:typegen2($type,$keytype,$valtype) {
(:	concat("n.",$type,"(n.",$keytype,"(),n.",$valtype,"())"):)
    concat("n.",$type,"()")
};

declare function core:typegen2($type,$seq) {
	if($type eq "map") then
		concat("n.map(",$seq,")")
	else
		()
};

declare function core:_typegen($args){
    if($args instance of xs:string) then
        "n._typegen($args)"
    else
        let $l := array:size($args)
        return
            if($l eq 2) then
                "n." || $args(1) || "(" || $args(2) || ")"
            else
                let $param := replace(rdl:camel-case(rdl:clip($args(2))),"\$","")
                return
                    if($args(3)) then
                		concat("$.",$args(1),"(&quot;",$param,"&quot;,",$args(3),")")
                	else
                		concat("$",replace($param,"^([^\.]*)(\.{3})$","$2 $1"))
};

declare function core:typegen($type) {
	core:_typegen([$type,""])
};

declare function core:typegen($type,$val) {
	core:_typegen([$type,$val])
};

declare function core:typegen($type,$frame,$name){
    core:_typegen([$type,$name,(),""])
};

declare function core:typegen($type,$frame,$name,$val){
	core:_typegen([$type,$name,$val,""])
};

declare function core:typegen($type,$frame,$name,$val,$suffix) {
	core:_typegen([$type,$name,$val,$suffix])
};
