#!/usr/bin/env bash

miner_stats=`curl --connect-timeout 2 --max-time $API_TIMEOUT --silent --noproxy '*' http://127.0.0.1:${MINER_API_PORT}/miner`
if [[ $? -ne 0 || -z $miner_stats ]]; then
  echo -e "${YELLOW}Failed to read $miner from localhost:{$MINER_API_PORT}${NOCOLOR}"
else
  local bus_numbers=`echo $miner_stats | jq -rc '.devices[] | select(.selected == true) | .pci_address [0:2]' | awk '{ printf "%d\n",("0x"$1) }' | jq -cs '.'`
  fan=`echo $miner_stats | jq -r ".devices[] | select(.selected == true) | .monitoring_info.fan_speed" | jq -cs '.'`
  temp=`echo $miner_stats | jq -r ".devices[] | select(.selected == true) | .monitoring_info.core_temperature" | jq -cs '.'`
  ver=`echo $miner_stats | jq -r ".version"`
  uptime=$(echo $miner_stats | jq -r ".uptime")
  stats=$(jq -n \
             --argjson fan "$fan" \
             --argjson temp "$temp" \
             --argjson bus_numbers "$bus_numbers" \
             --arg uptime "$uptime" \
             --arg ver "$ver" \
             '{$fan, $temp, $bus_numbers, $uptime, $ver}')

  local algos=`echo $miner_stats | jq -r '.algorithm' | tr + ' '`
  local i=1
  for t_algo in $algos; do
    t_khs=`echo $miner_stats | jq -r ".hashrate.$t_algo" | awk '{ printf("%.6f", $1/1000) }'`
    t_ac=`echo $miner_stats | jq -r ".solution_stat.$t_algo.accepted"`
    t_rj=`echo $miner_stats | jq -r ".solution_stat.$t_algo.rejected"`
    t_inv=`echo $miner_stats | jq -r ".solution_stat.$t_algo.invalid"`
    t_inv_gpu=`echo $miner_stats | jq -r ".devices[] | select(.selected == true) | .solution_stat.$t_algo.invalid" | tr "\n" ';'`; t_inv_gpu=${t_inv_gpu%%;}
    t_hs=`echo $miner_stats | jq -r ".devices[] | select(.selected == true) | .hashrate.$t_algo/1000" | jq -cs '.'`

  if [[ "$t_algo" == "ironfish" ]]; then
                hsunit="khs"
                algo="blake3-iron"
                t_hs=`echo $miner_stats | jq -r ".devices[] | select(.selected == true) | .hashrate.$t_algo/1000" | jq -cs '.'`
        else
                t_hs=`echo $miner_stats | jq -r ".devices[] | select(.selected == true) | .hashrate.$t_algo" | jq -cs '.'`
        fi

    [[ i -eq 1 ]] && local n= || local n=$i

    eval "khs$n=$t_khs"

    t_stats="{\"total_khs$n\": $t_khs, \"hs$n\": $t_hs, \"hs_units$n\": \"khs\", \"algo$n\": \"$t_algo\", \"ar$n\": [$t_ac, $t_rj, $t_inv, \"$t_inv_gpu\"]}"

    stats=$(jq -cs '.[0] * .[1]' <<< "$stats $t_stats")

    ((i++))
  done
fi

  [[ -z $khs ]] && khs=0
  [[ -z $stats ]] && stats="null"


#echo $stats
