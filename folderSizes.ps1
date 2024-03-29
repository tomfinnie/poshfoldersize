function Get-FolderSize{     
    
    param($path)
    
    $start = Get-Date
    
    $output = "c:\cs scripts\foldersize\"
    if (!(test-path $output)){md $output}
    $top = 100
    $top--

    $pathEscaped = $path.Replace(":\","_").Replace(":","_").Replace("\","_")

    Write-Progress -Activity "Retriving file details" -Status " "
    $items = gci -recurse $path
    $folders = $items | ?  {$_.psiscontainer}
    $files   = $items | ? {!$_.psiscontainer}

    $itemCount = $items.length
    $folderCount = $folders.length

    $folders | Add-Member -MemberType noteproperty -Name "depth" -value $null
    $folders | Add-Member -MemberType noteproperty -Name "ChildFilesSize" -value 0
    $folders | Add-Member -MemberType noteproperty -Name "ChildFoldersSize" -value 0
    $folders | Add-Member -MemberType noteproperty -Name "ChildTotalSize" -value 0
    $folders | Add-Member -MemberType noteproperty -Name "FriendlySize" -value 0
    $folders | Add-Member -MemberType noteproperty -Name "ChildFoldersCount" -value 0

    $files | Add-Member -MemberType noteproperty -Name "FriendlySize" -value 0

    $i = 0
    $folders | % {
        $fullname = $_.fullname
        $_.depth = ($_.fullname.split("\").length -1)
        Write-Progress -Activity "Calculating depth tree" -PercentComplete (10*$i / $folderCount) -Status "Studying $fullname"
        $i++}
        
    $folders = $folders | sort depth -Descending
    $minDepth = $folders[-1].depth

    $hash = @{}

    $i = 0
    $folders | % {
        Write-Progress -Activity "Preparing hash table" -PercentComplete (10+(20*$i / $folderCount)) -Status "Entry $i"
        $hash.add($_.fullname,$i)
        $i++
    }

    $i = 0
    $folders | % {
        
        $fullname = $_.fullname
        Write-Progress -Activity "Summing file sizes" -PercentComplete (30+(60*$i / $folderCount)) -Status "Studying $fullname"

        
        $parent = $_.fullname.remove($_.fullname.length - $_.name.length - 1)
        $parentIndex = $hash.$parent
        
        $_.ChildFilesSize = (gci $fullname  | Measure-Object -Sum length -ErrorAction silentlycontinue ).sum
        $_.ChildTotalSize = $_.ChildFilesSize + $_.ChildFoldersSize
        if ($_.depth -gt $minDepth) {
            $folders[$parentIndex].ChildFoldersSize += $_.ChildTotalSize
            $folders[$parentIndex].ChildFoldersCount += ($_.ChildFoldersCount + 1) }
        $i++
    }

    $folders | % {
         
         Write-Progress -Activity "Making folder sizes more friendly" -PercentComplete 91 -Status " "
         $mb = [math]::round($_.childtotalsize/1048576,0)
         $mbString = $mb.tostring()+" MB"
         
         $_.FriendlySize = $mbString
    }

    $files | % {
         Write-Progress -Activity "Making file sizes more friendly" -PercentComplete 93 -Status " "
         $mb = [math]::round($_.length/1048576,0)
         $mbString = $mb.tostring()+" MB"
         
         $_.FriendlySize = $mbString
    }

    $extHash = @{}

    $files | % {
        Write-Progress -Activity "Summing extension sizes" -PercentComplete 96 -Status " "
        $size = $_.length
        $extension = $_.extension
        $extHash.$extension += $size
        }
        
    $extensions = $extHash.GetEnumerator() | sort-object value -Descending   
    $extensions | Add-Member -MemberType noteproperty -Name "FriendlySize" -value 0
    $extensions | % {
         Write-Progress -Activity "Making extension sizes more friendly" -PercentComplete 99 -Status " "
         $mb = [math]::round($_.value/1048576,0)
         $mbString = $mb.tostring()+" MB"
         
         $_.FriendlySize = $mbString
    }


     
    $taken = ((get-date) - $start).totalseconds
    $ips = [math]::round($itemCount/$taken,1)

    $taken = [math]::round($taken,1)
        
    $folders | sort fullname | select fullname,childtotalsize
    ($folders   | sort childtotalsize -descending)| select fullname,friendlysize,ChildFoldersCount,CreationTime,LastAccessTime,LastWriteTime | export-csv ($output+"FOLDERS_"+$pathEscaped+".csv") -NoTypeInformation
    ($files     | sort length         -descending)[0..$top] | select fullname,friendlysize,CreationTime,LastAccessTime,LastWriteTime | export-csv ($output+"FILES_"+$pathEscaped+".csv") -NoTypeInformation
    ($extensions| sort value          -descending)[0..$top] | select name,friendlysize,value | export-csv ($output+"EXTENSIONS_"+$pathEscaped+".csv") -NoTypeInformation

    Write-Host "Query on $path took $taken seconds, for $itemCount items, ie $ips IPS"

}