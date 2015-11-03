xquery version "3.0";

module namespace n="http://raddle.org/n";

declare function n:if($test,$true,$false) {
    if($test) then
        $true
    else
        $false
};