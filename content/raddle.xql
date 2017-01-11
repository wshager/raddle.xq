xquery version "3.1";

module namespace rdl="http://raddle.org/raddle";
import module namespace xqc="http://raddle.org/xquery-compat" at "../lib/xq-compat.xql";
import module namespace n="http://raddle.org/native-xq" at "../lib/n.xql";
import module namespace a="http://raddle.org/array-util" at "../lib/array-util.xql";

import module namespace console="http://exist-db.org/xquery/console";

declare variable $rdl:suffix := "\+\*\-\?";
declare variable $rdl:ncname := $xqc:ncname;

declare variable $rdl:chars := $rdl:suffix || $rdl:ncname || "\$%/#@\^:";

declare variable $rdl:paren-regexp := concat("(\)[",$rdl:suffix,"]?)|(",$xqc:operator-regexp,"|,)?([",$rdl:chars,"]*)(\(?)");
declare variable $rdl:protocol-regexp := "^((http[s]?|ftp|xmldb|xmldb:exist|file):/)?/*(.*)$";

declare variable $rdl:operators := map {
	3: "|",
	4: "&amp;",
	5.01: "=eq=",
	5.02: "=ne=",
	5.03: "=lt=",
	5.04: "=le=",
	5.05: "=gt=",
	5.06: "=ge=",
	5.07: "=",
	5.08: "!=",
	5.09: "=<==",
	5.10: "=>==",
	5.11: "=<<=",
	5.12: "=>>=",
	5.13: "=<=",
	5.14: "=>=",
	6: "||",
	8.01: "+",
	8.02: "-",
	9.01: "*",
	9.02: "idiv",
	9.03: "div",
	9.04: "mod",
	17.01: "+",
	17.02: "-",
	18: "!",
	20.01: "[",
	20.02: "]",
	20.04: "[",
	20.06: "{",
	20.07: "}",
	21.01: "array",
	21.02: "attribute",
	21.03: "comment",
	21.04: "document",
	21.05: "element",
	21.06: "function",
	21.07: "map",
	21.08: "namespace",
	21.09: "processing-instruction",
	21.10: "text",
	22.01: "array",
	22.02: "attribute",
	22.03: "comment",
	22.04: "document-node",
	22.05: "element",
	22.06: "empty-sequence",
	22.07: "function",
	22.08: "item",
	22.09: "map",
	22.10: "namespace-node",
	22.11: "node",
	22.12: "processing-instruction",
	22.13: "schema-attribute",
	22.14: "schema-element",
	22.15: "text",
	25.01: "(:",
	25.02: ":)",
	26: ":"
};

declare variable $rdl:operator-map := map {
	3:"or",
	4:"and",
	5.01: "eq",
	5.02: "ne",
	5.03: "lt",
	5.04: "le",
	5.05: "gt",
	5.06: "ge",
	5.07: "geq",
	5.08: "gne",
	5.09: "gle",
	5.10: "gge",
	5.11: "precedes",
	5.12: "follows",
	5.13: "glt",
	5.14: "ggt",
	6: "concat",
	8.01: "add",
	8.02: "subtract",
	9.01: "multiply",
	10.02: "union",
	17.01: "plus",
	17.02: "minus",
	18: "for-each",
	19.01: "select",
	20.01: "filter",
	20.03: "lookup",
	20.04: "array",
	27.01: "pair"
};

declare function rdl:map-put($map,$key,$val){
	map:new(($map,map {$key : $val}))
};

declare function rdl:parse-strings($strings,$normalizer,$params) {
    (: TODO write wrapper function that adds strings to map uniquely, only incrementing per string (double entry) :)
    let $string := $strings("$%0")
	let $string := $normalizer($string,$params)
	let $parts := if(empty(tail($string))) then tokenize($string,";") else $string
	(: TODO detect RQL :)
	(: check for allowed/known filter operators up until any top level ops / aggregators :)
	(: if RQL, wrap with select(*,filter(...),top-level-ops) and aggregators :)
	return array:join(for-each($parts,function($block){
	    rdl:wrap(analyze-string($block,$rdl:paren-regexp)/fn:match,$strings,$params)
	}))
};

declare function rdl:normalize-query($query as xs:string?,$params){
    replace($query,"\s","")
};

declare function rdl:process-strings($strings,$ret,$index) {
    if(empty($strings)) then
        $ret
    else
        let $head := head($strings)
        return
            if(name($head) eq "match") then
                let $string := $head/string()
                let $index := if(map:contains($ret,$string)) then $index else $index + 1
                let $key := "$%" || $index
                let $ret := map:put($ret, $key, concat("&quot;",rdl:clip-string($string),"&quot;"))
                let $ret := map:put($ret,"$%0",concat($ret("$%0"),$key))
                return rdl:process-strings(tail($strings),$ret,$index)
            else
                let $ret := map:put($ret,"$%0",concat($ret("$%0"),$head/string()))
                return rdl:process-strings(tail($strings),$ret,$index)
};

declare function rdl:parse($query as xs:string?){
	rdl:parse($query,map {})
};

declare function rdl:parse($query as xs:string?,$params) {
    let $params := if(matches($query,"^\s*xquery\s+version")) then map:put($params,"$compat","xquery") else $params
    let $strings := rdl:process-strings(analyze-string($query,"('[^']*')|(&quot;[^&quot;]*&quot;)")/*,map { "$%0" : "" } , 1)
    let $params :=
        if($params("$compat") eq "xquery") then
            map:put(map:put($params,"$operators",$xqc:operators),"$operator-map",$xqc:operator-map)
        else
            map:put(map:put($params,"$operators",$rdl:operators),"$operator-map",$rdl:operator-map)
	return
    	rdl:parse-strings(
    		$strings,
	        xqc:normalize-query#2,
    		$params
    	)
};

declare function rdl:clip-string($str as xs:string) {
	substring($str,2,string-length($str)-2)
};

declare function rdl:value-from-strings($val as xs:string?,$strings) {
	if($val) then
    	if(matches($val,"\$%[0-9]+")) then
    		$strings($val)
    	else
    		$val
    else
        ""
};

declare function rdl:upsert($ret,$index,$val) {
    if(array:size($ret) lt $index) then
        array:append($ret,[$val])
    else
        a:put($ret,$index,array:append($ret($index),$val))
};

declare function rdl:wrap-qname($args) {
    if($args instance of map(xs:string,item()?)) then
        map {
            "name" := $args("name"),
            "args" := array:for-each($args("args"),function($arg){
                if($arg instance of xs:string and matches($arg,$xqc:qname)) then
                    map {
                        "name" := "core:select",
                        "args" := [".",$arg],
                        "suffix" := ""
                    }
                else
                    rdl:wrap-qname($arg)
            }),
            "suffix" := ""
        }
    else if($args instance of array(item()?)) then
        array:for-each($args,function($arg){
            if($arg instance of xs:string and matches($arg,$xqc:qname)) then
                map {
                    "name" := "core:select",
                    "args" := [".",$arg],
                    "suffix" := ""
                }
            else
                rdl:wrap-qname($arg)
        })
    else
        $args
};

declare function rdl:find-context-item($value) {
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
        					(: only check strings in sequence :)
        					if($_("name") = ("","last","fn:last")) then
    					        ()
        					else if($_("name") eq "core:filter") then
    					        rdl:find-context-item([$_("args")(1)])
        					else
        					    rdl:find-context-item($_("args"))
        				else
        				    ()
        			})
        		)
};

declare function rdl:wrap($match,$strings,$params){
	rdl:wrap($match,$strings,$params,[])
};

declare function rdl:wrap($match,$strings,$params,$ret){
	rdl:wrap($match,$strings,$params,$ret,1)
};

declare function rdl:wrap($match,$strings,$params,$ret,$depth){
	rdl:wrap($match,$strings,$params,$ret,$depth,false())
};

declare function rdl:wrap($match,$strings,$params,$ret,$depth,$was-comma){
    if(empty($match)) then
        $ret(1)
    else
        let $group := head($match)/fn:group
        let $rest := tail($match)
	    let $separator := $group[@nr=2]/string()
	    let $value := rdl:value-from-strings($group[@nr=3]/string(),$strings)
	    let $is-comma := matches($separator,",")
	    let $is-op := $is-comma = false() and matches($separator,$xqc:operator-regexp || "+")
	    let $op := if($is-op) then xqc:op-num($separator) else ()
		return if($group/@nr = 4) then
		    (: if operator, the remainder should be wrapped around ret, depending on operator precedence :)
		    let $ret :=
    		    if($is-comma) then
    		        rdl:upsert($ret,$depth,map { "name" := $value, "args" := [], "suffix" := ""})
    		    else if($is-op) then
    		        let $operator := xqc:to-op($op,$params)
    		        let $dest := if(array:size($ret) lt $depth) then [] else $ret($depth)
    		        let $len := array:size($dest)
    				let $last := if($len gt 0) then $dest($len) else ()
    				let $filter := $op eq 20.01
    				let $filter-context :=
    				    if($filter and $depth gt 1) then
        				    let $prev := $ret($depth - 1)
        				    let $s := array:size($prev)
        				    return $prev($s)
    				    else
    				        ()
    				let $select-filter := $filter-context instance of map(xs:string,item()?) and $filter-context("op") eq 19.01
                    return
                        if($op = $xqc:lr-op or ($filter and $select-filter eq false())) then
                            let $args := if($op = (19.01,20.01) and $value eq "") then [] else [map {"name" := $value,"args" := [], "suffix" := ""}]
                            let $prev-op :=
                                if($last instance of map(xs:string,item()?) and map:contains($last,"op")) then
                                    $last("op")
                                else
                                    ()
                            let $has-preceding-op := exists($prev-op) and $prev-op = $xqc:lr-op
                            let $is-unary-op :=
            				    if(round($op) = (8,17)) then
            				        $was-comma or $has-preceding-op
        				        else
        				            false()
        	                let $preceeds := $has-preceding-op and round($op) gt round($prev-op)
                            return
                                if($is-unary-op) then
                                    let $operator := xqc:to-op(xqc:unary-op($op),$params)
                                    let $dest :=
                            	        if($preceeds and array:size($last("args")) lt 2) then
                                			a:put($dest,$len,map:put($last,"args",[$last("args")(1),map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op, "nest" := $value ne ""}]))
                            	        else
                    	                array:append($dest,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op, "nest" := $value ne ""})
                    	            return a:put($ret,$depth,$dest)
                                else if($preceeds) then
                                    let $args := array:insert-before($args,1,$last("args")(2))
                                    let $dest := a:put($dest,$len,map:new(($last,map {
                                        "args" := [$last("args")(1),map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op }],
                                        "nest" := true()
                                    })))
                                    return a:put($ret,$depth,$dest)
                                else
                                    let $args := array:insert-before($args,1,$last)
                                    let $dest := a:put($dest,$len,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op, "nest" := $value ne "" })
                                    return a:put($ret,$depth,$dest)
                        else
                            if($value ne "") then
                                let $args := [$last,map { "name" := $value, "args" := [], "suffix" := ""}]
                                let $dest := a:put($dest,$len,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op, "nest" := $value ne ""})
        				        return a:put($ret,$depth,$dest)
                            else
                                rdl:upsert($ret,$depth,map { "name" := $operator, "args" := [], "suffix" := "", "op" := $op})
    		    else
    		        rdl:upsert($ret,$depth,map { "name" := $value, "args" := [], "suffix" := "", "call" := array:size($ret) ge $depth and $value eq ""})
    		return rdl:wrap($rest,$strings,$params,$ret,$depth+1,$is-comma and $value eq "")
		else if($value or $is-comma or $is-op) then
		    let $ret :=
		        if($is-op) then
		            if(array:size($ret) lt $depth) then
		                (: single unary :)
		                let $op := xqc:unary-op($op)
		                let $args := if($value ne "") then [$value] else []
        				let $operator := xqc:to-op($op,$params)
        				return array:append($ret,[map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op}])
		            else
    		            let $dest := $ret($depth)
                        let $len := array:size($dest)
        				let $last := $dest($len)
        				let $prev-op :=
                            if($last instance of map(xs:string,item()?) and map:contains($last,"op")) then
                                $last("op")
                            else
                                ()
        				let $has-preceding-op := exists($prev-op) and $prev-op = $xqc:lr-op
    	                let $is-unary-op :=
        				    if(round($op) = (8,17)) then
        				        $was-comma or $has-preceding-op
    				        else
    				            false()
    				    let $preceeds := $has-preceding-op and round($op) gt round($prev-op)
        				let $op :=
                    		if($is-unary-op) then
                    			xqc:unary-op($op)
                    		else
                    			$op
                    	let $operator := xqc:to-op($op,$params)
                    	let $dest :=
                    	    if($is-unary-op) then
                    	        let $args :=
                    				if($value ne "") then
                    					[$value]
                    				else
                    					[]
                    			return
                        	        if($preceeds and array:size($last("args")) lt 2) then
                            			a:put($dest,$len,map:put($last,"args",[$last("args")(1),map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op}]))
                        	        else
                    	                array:append($dest,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op})
                	        else if($preceeds) then
                	            let $args := [$last("args")(2)]
                    			let $args :=
                    				if($value ne "") then
                    					array:append($args,$value)
                    				else
                    					$args
                    			let $next := map:put($last,"args",[$last("args")(1),map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op}])
                				return a:put($dest,$len,$next)
                	        else
                			    let $args := if($value ne "") then [$last,$value] else [$last]
                				return a:put($dest,$len,map { "name" := $operator, "args" := $args, "suffix" := "", "op" := $op})
        				return
    		                a:put($ret,$depth,$dest)
		        else if($value ne "") then
		            rdl:upsert($ret,$depth,$value)
		        else
		            $ret
			return rdl:wrap($rest,$strings,$params,$ret,$depth,$is-comma and $value eq "")
		else if($group/@nr = 1) then
		    if(array:size($ret) lt $depth or $depth lt 2) then
		        let $suffix := replace($group/string(),"\)","")
		        let $ret :=
		            if($suffix ne "") then
        	            let $dest := $ret($depth - 1)
            		    let $len := array:size($dest)
            		    let $last := map:put($dest($len),"suffix",$suffix)
            		    let $dest := a:put($dest,$len,$last)
        		        return a:put($ret,$depth - 1, $dest)
        		    else
        		        $ret
		        return rdl:wrap($rest,$strings,$params,$ret,$depth - 1)
		    else
	            let $args := $ret($depth)
	            let $dest := $ret($depth - 1)
    		    let $len := array:size($dest)
    		    let $last := $dest($len)
    		    let $s := array:size($last("args"))
	            let $next := if($s gt 0) then $last("args")($s) else ()
	            let $nest := $next instance of map(xs:string,item()?) and ($last("nest") or $next("name") eq "")
	            let $op := if($nest) then $next("op") else if($last instance of map(xs:string,item()?)) then $last("op") else ()
	            let $args :=
	                if($nest) then
	                    let $ns := array:size($next("args"))
    		            let $maybeseq := if($ns gt 0) then $next("args")($ns) else ()
    		            let $is-seq := $maybeseq instance of map(xs:string,item()?) and $op ne 19.01 and map:contains($maybeseq,"op") eq false()
    		            return
    		                if($is-seq) then
    		                    a:put($next("args"),$ns,map:put($maybeseq,"args",array:join(($maybeseq("args"),$args))))
    		                else
    		                    array:join(($next("args"),$args))
    		        else
    		            array:join(($last("args"),$args))
    		    (:
	            this is for the implementation of xquery only
	            if no dot is found, look for a qname (or @qname)
	            or no qname is found expect fn:position instead
	            TODO: check for axis::qname
	            :)
	            let $args :=
	                if($op eq 19.01) then
	                    array:for-each($args,function($_){
	                        if($_ instance of map(xs:string,item()?)) then
	                            if($_("name") eq "") then
	                                $_
	                            else if(rdl:find-context-item([$_]) = ".") then
	                                map { "name" := "", "args" := [$_], "suffix" := "" }
	                            else
	                                $_
	                        else
	                            $_
	                    })
	                else if($op eq 20.01) then
	                    let $is-implicit := array:size($args) eq 1
	                    let $first :=
	                        if($is-implicit) then
	                            "."
	                        else
	                            let $first := $args(1)
	                            return
                                    if(rdl:find-context-item([$first]) = ".") then $first else rdl:wrap-qname([$first])(1)

                        let $second :=
                            if($is-implicit) then
                                $args(1)
                            else
                                $args(2)
                        let $second := if(rdl:find-context-item([$second]) = ".") then $second else rdl:wrap-qname([$second])(1)
                        let $second := if(rdl:find-context-item([$second]) = ".") then $second else map {
                            "name" := "core:geq",
                            "args" := [map {
                                "name" := "position",
                                "args" := ["."],
                                "suffix" := ""
                            },$second],
                            "suffix" := ""
                        }
                        let $second :=
                            map {
                                "name" := "",
                                "args" := [$second],
                                "suffix" := ""
                            }
                        return [$first, $second]
	                else
	                    $args
	            let $dest :=
    		        if($nest) then
    		            let $val := map { "name" := $next("name"), "args" := $args, "suffix" := "" }
    		            return a:put($dest,$len,map { "name" := $last("name"), "args" := a:put($last("args"),$s,$val), "suffix" := replace($group/string(),"\)",""), "op" := $last("op"), "nest" := $last("nest")})
    		        else
    		            let $val := map { "name" := $last("name"), "args" := $args, "suffix" := replace($group/string(),"\)",""), "call" := $last("call")}
    		            return a:put($dest,$len,$val)
		        return rdl:wrap($rest,$strings,$params,array:append(array:subarray($ret,1,$depth - 2),$dest),$depth - 1)
		else
	        $ret(1)
};

declare function rdl:import-module($name,$params){
	let $mappath :=
		if(map:contains($params,"modules")) then
			$params("modules")
		else
			"modules.xml"
	let $map := doc($mappath)/root/module
	let $location := xs:anyURI($map[@name = $name]/@location)
	let $uri := xs:anyURI($map[@name = $name]/@uri)
	let $module :=
		if($location) then
			inspect:inspect-module($location)
		else
			inspect:inspect-module-uri($uri)
	return n:try(util:import-module(xs:anyURI($module/@uri), $module/@prefix, xs:anyURI($module/@location)),())
};

declare function rdl:stringify($a,$params){
	rdl:stringify($a,$params,true())
};

declare function rdl:stringify($a,$params,$top){
	let $s := array:size($a)
	return
		a:fold-left-at($a,"",function($acc,$t,$i){
		    let $is-map := $t instance of map(xs:string?,item()?)
			let $ret :=
				if($is-map) then
					concat($t("name"),"(",string-join(rdl:stringify($t("args"),$params,false()),","),")",if($t("suffix") instance of xs:string) then $t("suffix") else "")
				else if($t instance of array(item()?)) then
					concat("(",rdl:stringify($t,$params,false()),")")
				else
					$t
			return concat($acc,
			    if($i gt 1) then
		            if($top) then
		                ";&#10;&#13;"
		            else if($is-map and $t("call")) then
			            ""
			        else
		                ","
			    else
			        "",$ret)
		})
};

declare function rdl:transpile($tree,$lang,$params){
    let $module := n:import("../lib/" || $lang || ".xql")
	let $frame := map:put($params,"$imports",map {
		"core": $module
	})
	let $func := $module("$exports")("core:transpile#2")
	return $func($tree,$frame)
};

declare function rdl:exec($query,$params){
	(: FIXME retrieve default-namespace :)
	let $core := n:import("../lib/core.xql")
	let $n := n:import("../lib/n.xql")
	return
		if(map:contains($params,"$transpile")) then
			if($params("$transpile") eq "rdl") then
				rdl:stringify(rdl:parse($query,$params),$params)
			else
				rdl:transpile(rdl:parse($query,$params),$params("$transpile"),$params)
		else
			let $frame := map:put($params,"$imports",map { "core": $core, "n": $n})
			let $fn := n:eval(rdl:parse($query,$params))
			return $fn($frame)
};

declare function rdl:clip($name){
	if(matches($name,"^&quot;.*&quot;$")) then rdl:clip-string($name) else $name
};

declare function rdl:camel-case($name){
	let $p := tokenize($name,"\-")
	return head($p) || string-join(for-each(tail($p),function($_){
		let $c := string-to-codepoints($_)
		return concat(upper-case(codepoints-to-string(head($c))),codepoints-to-string(tail($c)))
	}))
};

declare function rdl:capitalize($str){
	let $cp := string-to-codepoints($str)
	return codepoints-to-string((string-to-codepoints(upper-case(codepoints-to-string(head($cp)))),tail($cp)))
};
