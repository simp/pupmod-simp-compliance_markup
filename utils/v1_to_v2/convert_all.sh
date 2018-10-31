#!/bin/bash

set -e

compliance_map_migrate=$( realpath utils/compliance_map_migrate )
merge_el6_el7=$( realpath utils/v1_to_v2/merge_el6_el7.rb )

list_modules() {
    for file in CentOS/*/*.json ; do
        std=${file##*/}
        jq -r \
            '.["compliance_markup::compliance_map"]
            | .'"${std%.json}"'
            | keys
            | .[]' \
            $file
    done | sed 's/::.*//' | sort -u
}

cd data/compliance_profiles

modules=( $( list_modules ) )

for module in "${modules[@]}" ; do
    modulepath="../../../pupmod-simp-$module"
    if [ -d "$modulepath" ] ; then
        profilepath="$modulepath/SIMP/compliance_profiles"
        mkdir -pv "$profilepath"
        for n in 6 7 ; do
            args=()
            for file in CentOS/"$n"/*.json ; do
                args+=("-i" "$file")
            done
            if [ "$n" -eq 6 ] ; then
                args+=("-a" "el$n")
            fi
            "$compliance_map_migrate" ${args[@]} -o "$profilepath/checks-el$n.yaml" -m "$module" -c osfamily=RedHat -c operatingsystemmajrelease="$n"
        done
        ( cd "$profilepath" && "$merge_el6_el7" )
    else
        echo "Failed to find module path for $module" >&2
    fi
done
