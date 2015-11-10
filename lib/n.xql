xquery version "3.1";

module namespace n="http://raddle.org/n";

declare function n:if($test,$true,$false) {
    if($test) then
        $true
    else
        $false
};

declare function n:eq($a,$b) {
    $a eq $b
};

declare function n:select($a,$b) {
    util:eval("$a/" || $b)
};


declare function n:map() {
    map {}
};

declare function n:array() {
    []
};

declare function n:element($name,$content) {
    element {$name} {
        $content
    }
};

declare function n:attribute($name,$content) {
    attribute {$name} {
        $content
    }
};