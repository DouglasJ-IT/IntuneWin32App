##### Added Functions
1.  Added private function ConvertTo-Hashtable to take an unordered PSObject and return an [ordered] object.  Used so that Get-IntuneWin32AppDependency and Get-IntuneWin32AppSupersedence could return an [ordered] object arry since you need this type of object to call the Set- version of these commands.
1. Added private function ConvertTo-IntuneWin32RelationshipJSON.  When working with Supersedence and Dependencies if you wanted to assign a single Supersedence or no Supersedence (same with Dependencies) the standard ConvertTo-JSON would create JSON that the Graph API wouldn't accept.  This is my attempt to deal with these edge cases.
A relationship object with no relationships would be created as
```
{
  "relationships": null
}
```
The API's are looking for 
```

{ "relationships" : [  ] }

```
A relationship object with a single relationships was created by ConvertTo-JSON as
```
{
    "relationships":  {
                          "@odata.type":  "#microsoft.graph.mobileAppSupersedence",
                          "supersedenceType":  "update",
                          "targetId":  "c5944f4d-4434-4b3a-a933-3b92158f1ce9"
                      }
}
```
The API's are lookiung for this format
```
{ "relationships": [
    {
        "@odata.type":  "#microsoft.graph.mobileAppSupersedence",
        "supersedenceType":  "update",
        "targetId":  "c5944f4d-4434-4b3a-a933-3b92158f1ce9"
    }
] }
```

### Updates to Add-IntuneWin32ppDependency
1. Allowed the passing a empty $Dependency, this allow this function to remove all Dependencies.
1. Fixed the logic for pulling current supercedence.  You can only update the supersedence with "child" relationships.
1. Fixed the edge case for JSON conversion of single items.

### Updates to Add-IntuneWin32AppSupersedence
1. Allowed the passing a empty $Supersedence, this allow this function to remove all Supersedences.
1. Fixed the edge case for JSON conversion of single items.

### Updates to Get-IntuneWin32ppDependency
1. Return Dependency as an array of [ordered].  Should be in the same format as required by the Set function.
1. Fixed the logic to deal with multiple dependancies.

### Updates to Get-IntuneWin32AppSupersedence
1. Added a switch for -ChildOnly to return just the child supersedence.  This is useful when updating supersedence.
1. Return Supersedence as an array of [ordered].  Should be in the same format as required by the Set function.

### Updates to New-IntuneWin32AppDependency
1. Fixed syntax error

### Updates to Remove-IntuneWin32App
1. Added -Force switch to allow removal of app with dependancies or supersedences.  It will remove all child and parent supersedences and dependencies.

### Updates to Remove-IntuneWIn32AppDependency
1. Updated to fix JSON edge cases

### Updates to Remove-IntuneWIn32AppSupersedence
1. Updated to fix JSON edge cases
