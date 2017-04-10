xquery version "3.1";

module namespace core="http://raddle.org/javascript";

import module namespace rdl="http://raddle.org/raddle" at "../content/raddle.xql";
import module namespace a="http://raddle.org/array-util" at "array-util.xql";
import module namespace env="http://raddle.org/env" at "env.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare variable $core:typemap := map {
	"boolean": 0,
	"integer": 0,
	"decimal": 0,
	"double": 0,
	"string": 0,
	"item": 0,
	"anyURI": 0,
	"map": 2,
	"function": 1,
	"array": 1,
	"element": 1,
	"attribute": 1,
	"numeric": 0,
	"atomic": 0,
	"document-node": 0,
	"node": 0,
	"QName": 0
};

declare variable $core:native-ops := (
(:	"or",:)
(:	"and",:)
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

declare function core:and($a,$b){
    concat("$.test(",$a,") ",$env:AMP,$env:AMP," $.test(",$b,")")
};

declare function core:or($a,$b){
    concat("$.test(",$a,") || $.test(",$b,")")
};

declare function core:select($a){
    concat("n.select(",$a,")")
};

declare function core:select($a,$b){
    concat("n.select(",$a,",",$b,")")
};

declare function core:select($a,$b,$c){
    concat("n.select(",$a,",",$b,",",$c,")")
};

declare function core:select($a,$b,$c,$d){
    concat("n.select(",$a,",",$b,",",$c,",",$d,")")
};

declare function core:select($a,$b,$c,$d,$e){
    concat("n.select(",$a,",",$b,",",$c,",",$d,",",$e,")")
};

declare function core:select($a,$b,$c,$d,$e,$f){
    concat("n.select(",$a,",",$b,",",$c,",",$d,",",$e,",",$f,")")
};

declare function core:select($a,$b,$c,$d,$e,$f,$g){
    concat("n.select(",$a,",",$b,",",$c,",",$d,",",$e,",",$f,",",$g,")")
};

declare function core:find-context-item($value) {
	if($value instance of xs:string) then
	    concat("findContextItem(",$value,")")
	else
    	if(array:size($value) eq 0) then
    		()
    	else
    	    let $cx := array:filter($value,function($_) {
    	        $_ instance of xs:string and matches($_,"^\.$")
    	    })
    	    return
    	        if(array:size($cx) gt 0) then
    	            array:flatten($cx)
    	        else
    		        array:flatten(
            			a:for-each-at($value,function($_,$at){
            				if($_ instance of map(xs:string, item()?)) then
            					(: skip seqs :)
            					if($_("name") eq "") then
        					        ()
            					else
            					    core:find-context-item($_("args"))
            				else
            				    ()
            			})
            		)
};

declare function core:find-let-seq($value) {
	if($value instance of xs:string) then
	    concat("findLetSeq(",$value,")")
	else
    	if(array:size($value) eq 0) then
    		()
    	else
    		array:flatten(
    			a:for-each($value,function($_){
    				if($_ instance of map(xs:string, item()?)) then
    					(: only check strings in sequence :)
        				a:for-each-at($_("args"),function($_,$at){
            				if($_ instance of xs:string) then
            					if(matches($_,"^\$$")) then
            					    $value($at + 1)
            					else
            					    ()
            				else
            					()
            			})
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
	    core:process-args($frame,$args,"")
};

declare function core:process-args($frame,$args,$caller){
    if($frame instance of xs:string) then
	    concat("processArgs(",$frame,",",$args,",",$caller,")")
	else
	    core:process-args($frame,$args,$caller,"$_0")
};

declare function core:process-args($frame,$args,$caller,$nest){
	if($frame instance of xs:string) then
	    concat("processArgs(",$frame,",",$args,",",$caller,",",$nest,")")
	else
		let $is-defn := $caller = ("core:define-private#6","core:define-private#5","core:define#6","core:define#5")
		let $is-anon := $caller eq "core:anon#4"
		let $is-iff := $caller eq "core:iff#3"
		let $is-interop := $caller eq "core:interop#2"
		let $is-typegen := matches($caller,"^core:(typegen|" || string-join(map:keys($core:typemap),"|") || ")")
		return
			a:fold-left-at($args,[],function($pre,$arg,$at){
				if($arg instance of array(item()?)) then
				    if($is-interop) then
				        array:append($pre,$arg)
				    else
    					let $is-thenelse := $is-iff and $at = (2,3)
    					let $let-seq := core:find-let-seq($arg)
    					let $is-let-ret := count($let-seq) > 0
    					return
    					    array:append($pre,
    					        if($is-thenelse) then
    							    let $val := core:process-args($frame,$arg,"",$nest)
    							    let $s := array:size($val)
                                    let $ret :=
                                        if($s eq 0) then
                                            "return n.seq();"
                                        else if($s gt 1) then
                                            if($is-let-ret) then
                                                core:let-ret($val,$let-seq,())
                            			    else
                            			        concat("return n.seq(",string-join(array:flatten($val),","),");")
                            			else
                            			    concat("return ",$val(1),";")
    								return
    								    $ret
    							else
    							    a:for-each-at($arg,function($_,$at){
    									if($_ instance of array(item()?)) then
    										core:process-tree($_, $frame)
    									else
    										core:process-value($_,$frame,$at,$nest)
    								})
        					    )
				else if($arg instance of map(xs:string,item()?)) then
				    if(($is-defn and $at = 4) or
				        ($is-anon and $at = 2)) then
				        (: is params! :)
					    array:append($pre,$arg("args"))
					else
					    let $is-thenelse := $is-iff and $at = (2,3)
					    let $is-body := ($is-defn and $at = 6) or ($is-anon and $at = 4)
					    return
					        if($is-body or $is-thenelse) then
					            (: check for let-ret-seq only if is-seq :)
					            let $args := $arg("args")
					            let $arg :=
					                if($is-body and $arg("name") eq ""  and
					                array:size($args) eq 1 and
					                $args(1) instance of map(xs:string,item())) then
					                    $args(1)
					                else
					                   $arg
					            let $is-seq := $arg("name") eq ""
					            let $ret :=
					                if($is-seq) then
        					            let $args := $arg("args")
        					            let $let-seq := core:find-let-seq($args)
                    					let $is-let-ret := count($let-seq) > 0
                    					let $val := core:process-args($frame,$args,"",$nest)
        							    let $s := array:size($val)
                                        return
                                            if($s eq 0) then
                                                "return n.seq();"
                                            else if($s gt 1) then
                                                if($is-let-ret) then
                                                    core:let-ret($val,$let-seq,())
                                			    else
                                			        concat("return n.seq(",string-join(array:flatten($val),","),");")
                                			else
                                			    concat("return ",$val(1),";")
                                	else
                                	    let $ret := core:process-value($arg,$frame,$at)
                                	    return
                                	        if($is-body) then
                                	            concat("return ",$ret,";",$env:LF)
                                	        else
                                	            $ret
								return
						            array:append($pre,$ret)
						    else
        					    if($arg("name") eq "" and $at gt 1 and $arg("call")) then
        					        let $val := concat("n.call(",$pre($at - 1),",",core:process-value($arg,$frame,$at),")")
            					    return a:put($pre,$at - 1,$val)
            					else
            						array:append($pre,core:process-value($arg,$frame,$at,$nest))
				else if($arg eq ".") then
					array:append($pre,$nest)
				else if($arg eq "$") then
					array:append($pre,$frame)
				else if(matches($arg,"^\$[" || $rdl:ncname || "]+$")) then
					array:append($pre,if(matches($arg,"^\$\p{N}")) then
						replace($arg,"^\$","\$_")
					else
						core:serialize($arg,$frame))
				else if((($is-defn or $is-typegen) and $at eq 2) or ($is-interop and $at eq 1)) then
				    (: escape proper names :)
					array:append($pre,$arg)
				else if(matches($arg,"^_[" || $rdl:suffix || "]?$")) then
					array:append($pre,replace($arg,"^_","_" || $frame("$at")))
				else
					array:append($pre,core:serialize($arg,$frame))
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

declare function core:interop($name,$arities){
    if($arities instance of xs:string) then
        concat("interop(",$name,",",$arities,")")
    else
        let $parts := tokenize(rdl:clip($name),":")
    	let $fname := rdl:camel-case($parts[last()])
    	return
            concat(
                "export function ",$fname,"(...$_a) {",$env:LF,$env:TAB,
        	    "var $_l = $_a.length;",$env:LF,$env:TAB,
                string-join(for-each(array:flatten($arities),function($a){
                    let $has-rest-param := $a eq -1
                    return concat(
                        if($has-rest-param) then "" else concat("if($_l===",$a,"){",$env:LF,$env:TAB,$env:TAB),
                        "return ",$fname,"$",$a,".apply(this,$_a);",$env:LF,$env:TAB,
                        if($has-rest-param) then "" else concat("}",$env:LF,$env:TAB)
                    )
                })),
                $env:LF,$env:TAB,"return n.error(",$fname,",$_l);",$env:LF,"}"
            )
};


declare function core:transpile($value,$frame) {
	let $frame := map:put($frame,"$tree",$value)
	let $distinct := array:fold-left($value,map{},function($pre,$cur){
		if($cur("name") = ("core:define","core:define-private") and array:size($cur("args")) eq 6) then
			let $name := $cur("args")(2)
			let $argseq := $cur("args")(4)
			let $args := $argseq("args")
			let $arity := array:size($args)
			let $last := $args($arity)
        	let $has-rest-param :=
    	        if($last instance of map(xs:string,item()?)) then
    	            matches($last("args")(2),"^\.{3}")
    	        else
    	            matches($last,"^\.{3}")
        	let $arity :=
        	    if($has-rest-param) then
        	        -1
        	    else
        	        $arity
			return
			    if(map:contains($pre,$name)) then
			        map:put($pre,$name,array:append($pre($name),$arity))
			    else
			        map:put($pre,$name,[$arity])
		else
			$pre
	})
	let $value := array:join(($value,array {
	    map:for-each-entry($distinct,function($name,$arities){
	        map { "name": "core:interop", "args": [$name,$arities], "suffix": ""}
	    })
	}))
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
	    core:process-tree($tree,$frame,$top,"")
};

declare function core:process-tree($tree,$frame,$top,$ret) {
    if($tree instance of xs:string) then
	    concat("processTree(",$tree,",",$frame,",",$top,",",$ret,")")
	else
	    core:process-tree($tree,$frame,$top,$ret,1)
};

declare function core:process-tree($tree,$frame,$top,$ret,$at){
	(: TODO mirror n:eval :)
	(: TODO cleanup into process-args :)
    if($frame instance of xs:string) then
	    concat("processTree(",$tree,",",$frame,",",$top,",",$ret,",",$at,")")
	else if(array:size($tree) gt 0) then
		let $head := array:head($tree)
		let $frame :=
		    if($head instance of map(xs:string,item()?) and $head("name") eq "core:module") then
		        map:put($frame,"$prefix",$head("args")(2))
		    else
		        $frame
		let $is-seq := $head("name") eq ""
		let $let-seq := core:find-let-seq($head("args"))
		let $is-let-ret := count($let-seq) > 0
		let $val := core:process-value($head,$frame,$at)
		let $val :=
			if($is-seq) then
			    if($is-let-ret) then
			        concat("(",string-join(array:flatten($val),","),")")
			    else
		            concat("n.seq(",string-join(array:flatten($val),","),")")
			else
				$val
		let $ret := concat(
		    $ret,
		    if($ret ne "" and $at > 1) then
		        if($top) then concat($env:LF,$env:LF) else concat(",",$env:LF)
		    else
		        "",
		    $val)
		return core:process-tree(array:tail($tree),$frame,$top,$ret,$at + 1)
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

declare function core:process-value($value,$frame,$at){
    if($frame instance of xs:string) then
        concat("processValue(",$value,",",$frame,",",$at,")")
    else
        core:process-value($value,$frame,$at,"$_0")
};

declare function core:process-value($value,$frame,$at,$nest){
    if($frame instance of xs:string) then
        concat("processValue(",$value,",",$frame,",",$at,",",$nest,")")
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
				let $is-defn := $local = ("define","define-private","anon")
				let $is-fn :=
				    ($is-defn and ($s eq 6 or $s eq 5)) or
				    ($local eq "anon" and $s eq 4) or
				    ($local eq "interop")
(:				    or :)
(:				    ($local eq "iff"):)
				let $let-ret :=
				    if($is-type and $s gt 1) then
				        let $_ := $args($s - 1)
				        return
				            if($_ instance of map(xs:string,item()?) and $_("name") eq "") then
				                core:find-let-seq($_("args"))
				            else
				                ()
				    else
				        ()
				let $args := core:process-args($frame,$args,concat($name,"#",$s),$nest)
				let $args :=
					if($is-type or $is-native) then
						(: TODO append suffix :)
						array:insert-before($args,1,$local)
					else
						$args
				let $args :=
					a:for-each-at($args,function($_,$i){
					    if($is-type and $i eq $s and count($let-ret) gt 0) then
					        concat("($ => {",core:let-ret($_,$let-ret,()),"})($.frame())")
				        else if($_ instance of array(item()?) and $is-fn eq false()) then
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
						let $nu := console:log($a)
						return function-lookup(QName("http://raddle.org/javascript", $f),$s)
					else if($is-native) then
						function-lookup(QName("http://raddle.org/javascript", "core:native"),$s)
					else
						function-lookup(QName("http://raddle.org/javascript", $name),$s)
				let $n := if(empty($fn)) then console:log(($name,"#",$s,":",$args)) else ()
				let $ret := apply($fn,$args)
				return
				        $ret
			else if($name eq "") then
			    let $cx := core:find-context-item($args)
				let $args := a:for-each(core:process-args($frame,$args),function($_){
    					if($_ instance of array(item()?)) then
    						concat("n.seq(",string-join(array:flatten($_),","),")")
    					else
    						$_
    				})
				return
				    if($cx = ".") then
				        concat("$_0 => ",string-join(array:flatten($args),""))
				    else
				        $args
			else
				let $args := core:process-args($frame,$args,concat($name,"#",$s),$nest)
				(: FIXME add check for seq calls :)
				let $ret :=
					a:fold-left-at($args,"",function($pre,$cur,$at){
						concat($pre,
							if($at>1) then "," else "",
							if($cur instance of array(item()?)) then
								concat("n.seq(",string-join(array:flatten($cur),","),")")
							else if($cur instance of map(xs:string,item()?)) then
								core:process-value($cur,$frame,$at,$nest)
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
		replace($value,"^_","\$_" || $at)
	else
		core:serialize($value,$frame)
};

declare function core:is-current-module($frame,$name){
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
				concat("$(",$env:QUOT,replace($parts,"^\$",""),$env:QUOT,")")
(:                $parts:)
			else if(matches($parts[1],concat("^\$?",$frame("$prefix")))) then
				replace($parts[last()],"\$","")
			else
				concat(replace($parts[1],"\$",""),".",$parts[2])
	else if(matches($string,concat("^(",$env:QUOT,"[^",$env:QUOT,"]*",$env:QUOT,")$"))) then
		concat("n.string(",replace($string,"\\","\\\\"),")")
	else if(map:contains($core:auto-converted,$string)) then
		$core:auto-converted($string)
	else
		if(string(number($string)) = "NaN") then
			concat("n.string(",$env:QUOT,replace($string,"\\","\\\\"),$env:QUOT,")")
		else if(matches($string,"\.")) then
			concat("n.decimal(",$string,")")
		else
			concat("n.integer(",$string,")")
};

declare function core:serialize($value,$params){
    if($params instance of xs:string) then
        concat("serialize(",$value,",",$params,")")
    else
    	if($value instance of map(xs:string, item()?)) then
    		concat($value("name"),
    		    if(map:contains($value,"args")) then
    		        core:serialize($value("args"),$params)
    		    else
    		        "()"
    		    ,
    		    if(map:contains($value,"suffix")) then $value("suffix") else ""
    	    )
    	else if($value instance of array(item()?)) then
    		    a:fold-left-at($value,"",function($pre,$cur,$at){
    			    let $is-seq := ($cur instance of map(xs:string, item()?) and $cur("name") eq "")
    			    return concat($pre,
        				if($at>1 and $is-seq=false()) then "," else "",
        				core:serialize($cur,$params)
        			)
    		    })
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
	concat("/*module namespace ", rdl:clip($prefix), "=", $ns, ";",$env:LF,$desc,"*/")
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
		concat("import * as ", rdl:clip($prefix), " from ", replace($loc,concat("(\.xql|\.rdl)",$env:QUOT,"$"),concat(".js",$env:QUOT)), "")
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

declare function core:cardinality($a){
    if($a instance of xs:string) then
        concat("cardinality(",$a,")")
    else
        let $suffix := $a(1)
        let $card :=
            if($suffix eq "+") then
                "n.oneOrMore"
            else if($suffix eq "*") then
                "n.zeroOrMore"
            else if($suffix eq "?") then
                "n.zeroOrOne"
            else
                ""
        return
            $card
};

declare function core:composite-type($composite) {
    if($composite instance of xs:string) then
        concat("composite-type(",$composite,")")
    else
        string-join(array:flatten(array:for-each($composite,function($_){
            if($_ instance of xs:string) then
                core:cardinality([$_])
            else if($_("name") eq "") then
                concat("(",core:composite-type($_("args")),")")
            else
                concat(replace($_("name"),"core:","\$."),"(",core:cardinality([$_("suffix")]),")")
        })),",")
};

declare function core:define($frame,$name,$def,$args,$type,$body,$private) {
    if($frame instance of xs:string) then
        concat("define(",$frame,",",$name,",",$def,",",$args,",",$type,",",$body,",",$private,")")
    else
    	(:
    	let $params :=
    	    array:flatten(a:for-each($args,function($_){
    	        if($_ instance of map(xs:string,item()?)) then
    			    concat("$",$_("args")(2))
        		else if($_ instance of xs:string) then
    				$_
        		else
        			()
    	    }))
    	:)
    	let $arity := array:size($args)
    	let $has-rest-param :=
    	    let $last := $args($arity)
    	    return
    	        if($last instance of map(xs:string,item()?)) then
    	            matches($last("args")(2),"^\.{3}")
    	        else
    	            matches($last,"^\.{3}")
    	let $arity :=
    	    if($has-rest-param) then
    	        ""
    	    else
    	        $arity
    	let $init :=
    	    array:for-each($args,function($_){
    	        if($_ instance of map(xs:string,item()?)) then
    	            let $args := $_("args")
    	            let $param := $args(2)
    	            let $param :=
    	                if(matches($param,"^\p{N}+$")) then
    	                    $param
    	                else
    	                    concat($env:QUOT,rdl:camel-case($param),$env:QUOT)
    	            let $card := core:cardinality([$_("suffix")])
        			return concat(
        			    replace(replace($_("name"),"core:",concat($env:TAB,".")),"function","func"),
        			    "(",$param,
        			    if(array:size($args) gt 2) then
        			        concat(",",core:composite-type(array:subarray($args,3)))
        			    else
        			        "",
        			    if($card ne "") then concat(",",$card) else "",
        			    ")")
        		else if($_ instance of xs:string) then
    				concat("$.item(",$_,")")
        		else
        			$_
    	    })
    	let $init := string-join(array:flatten($init),concat($env:LF,$env:TAB))
    	let $parts := tokenize(rdl:clip($name),":")
    	let $fname := rdl:camel-case($parts[last()])
    	let $aname := concat($fname,"$",$arity)
    	return concat(
    	    if($private) then "" else "export ",
            "function ",$aname,"(...$_a) {",$env:LF,$env:TAB,
            "var $ = n.frame($_a)",$env:LF,$env:TAB,
            $init,";",$env:LF,$env:TAB,
            if($body eq "") then concat("return ",$parts[1],".",$fname,".apply(this,$_a);") else $body,
            $env:LF,"}"
        )
};

declare function core:describe($frame,$name,$def,$args,$type){
	"n.map()"
};

declare function core:anon($frame,$args,$type,$body) {
    if($frame instance of xs:string) then
        concat("anon(",$args,",",$type,",",$body,")")
    else
    	(:
    	let $params :=
    	    array:flatten(a:for-each($args,function($_){
    	        if($_ instance of map(xs:string,item()?)) then
    			    concat("$",$_("args")(2))
        		else if($_ instance of xs:string) then
    				$_
        		else
        			()
    	    }))
    	:)
    	let $init :=
    	    array:flatten(a:for-each($args,function($_){
    	        if($_ instance of map(xs:string,item()?)) then
    	            let $args := $_("args")
    	            let $param :=  concat($env:QUOT,rdl:camel-case($args(2)),$env:QUOT)
    	            let $composite := array:flatten(array:subarray($args,3))
    	            let $card := core:cardinality([$_("suffix")])
    	            return concat(
        			    replace($_("name"),"core:",concat($env:TAB,".")),
        			    "(",$param,
        			    for-each($composite,function($_){
        			        concat(",",replace($_("name"),"core:","\$."),"(",core:cardinality([$_("suffix")]),")")
        			    }),
        			    if($card ne "") then concat(",",$card) else "",
        			    ")")
        		else if($_ instance of xs:string) then
    				concat("$.item(",$_,")")
        		else
        			$_
    	    }))
    	return concat(
            "function (...$_a) {",$env:LF,$env:TAB,
            "$ = $.frame($_a)",$env:LF,$env:TAB,
            string-join($init,concat($env:LF,$env:TAB)),";",$env:LF,$env:TAB,
            $body,$env:LF,"}"
        )
};

declare function core:let-ret($a,$let-seq,$seqtype){
    if($a instance of xs:string) then
        concat("letRet(",$a,",",$let-seq,",",$seqtype,")")
    else
        let $size := array:size($a)
        return string-join(array:flatten(a:for-each-at($a,function($_,$at) {
            let $_ :=
                if($_ instance of array(item()?)) then
                    concat("n.seq(",string-join(array:flatten($_),","),")")
                else
                    $_
            return
                if($at lt $size) then
                    concat("$ = ",$_)
                else
                    concat(
                        "return ",
                        if($seqtype) then
                            concat(substring($seqtype,1,string-length($seqtype) - 1),$_,")")
                        else
                            $_,
                        ";",$env:LF,$env:TAB
                    )
        })),concat(";",$env:LF,$env:TAB))
};

declare function core:iff($a,$b,$c){
    let $d := concat($env:LF,$env:TAB)
    return
    	concat(
            "($ => {",$d,"if($.test(",
            $a,
            ")) {",$d,$env:TAB,
            if(matches($b,"^return|^\$ =")) then $b else concat("return ",$b,";"),$d,
            "} else {",$d,$env:TAB,
            if(matches($c,"^return|^\$ =")) then $c else concat("return ",$c,";"),$d,
            "}",$d,"})($.frame())"
        )
};

declare function core:typegen1($type,$seq) {
    concat("n.",$type,"(",$seq,")")
};

declare function core:typegen1($type,$name,$seq) {
	concat("n.",$type,"(",$name,",",$seq,")")
};

declare function core:typegen2($type) {
	$type
};

declare function core:typegen2($type,$keytype,$valtype,$body) {
    concat("n.map(",$body,")")
};

declare function core:typegen2($type,$keytype,$valtype) {
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
        concat("_typegen(",$args,")")
    else
        let $l := array:size($args)
        return
            if($l eq 2) then
                concat("n.",$args(1), "(" ,$args(2), ")")
            else
                let $param := rdl:camel-case(rdl:clip($args(2)))
                return
                    if($args(3)) then
                		concat("$(",$env:QUOT,$param,$env:QUOT,",",$args(3),")")
                	else
                		concat("$(",$env:QUOT,replace($param,"^([^\.]*)(\.{3})$","$2 $1"),$env:QUOT,")")
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
