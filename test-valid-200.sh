#!/usr/bin/env bash

set +e

make add-frac >/tmp/add-frac-build.log
if [ $? -ne 0 ]; then
    cat /tmp/add-frac-build.log
    exit 1
fi

total=0
failed=0

gcd_abs() {
    local a="$1"
    local b="$2"
    local t

    if (( a < 0 )); then
        a=$(( -a ))
    fi
    if (( b < 0 )); then
        b=$(( -b ))
    fi

    while (( b != 0 )); do
        t=$(( a % b ))
        a="$b"
        b="$t"
    done

    printf '%d' "$a"
}

expected_sum() {
    local n1="$1"
    local d1="$2"
    local n2="$3"
    local d2="$4"
    local rn=$(( n1 * d2 + n2 * d1 ))
    local rd=$(( d1 * d2 ))
    local g

    if (( rd == 0 )); then
        if (( rn == 0 )); then
            printf 'NaN ("not a number")'
        elif (( rn < 0 )); then
            printf -- '-\342\210\236'
        else
            printf '+\342\210\236'
        fi
        return
    fi

    if (( rn == 0 )); then
        printf '0'
        return
    fi

    g=$(gcd_abs "$rn" "$rd")
    rn=$(( rn / g ))
    rd=$(( rd / g ))

    if (( rd < 0 )); then
        rn=$(( -rn ))
        rd=$(( -rd ))
    fi

    if (( rd == 1 )); then
        printf '%d' "$rn"
    else
        printf '%d/%d' "$rn" "$rd"
    fi
}

run_case() {
    local arg1="$1"
    local arg2="$2"
    local n1="$3"
    local d1="$4"
    local n2="$5"
    local d2="$6"
    local expected
    local out_file
    local err_file
    local actual_out
    local actual_err
    local status

    total=$(( total + 1 ))
    expected=$(expected_sum "$n1" "$d1" "$n2" "$d2")
    out_file=$(mktemp)
    err_file=$(mktemp)

    ./add-frac "$arg1" "$arg2" >"$out_file" 2>"$err_file"
    status=$?
    actual_out=$(cat "$out_file")
    actual_err=$(cat "$err_file")
    rm -f "$out_file" "$err_file"

    if [ "$actual_out" != "$expected" ] || [ -n "$actual_err" ]; then
        failed=$(( failed + 1 ))
        printf 'FAIL case %03d: ./add-frac %q %q\n' "$total" "$arg1" "$arg2"
        printf '  exit=%s\n' "$status"
        printf '  stdout=%q\n' "$actual_out"
        printf '  stderr=%q\n' "$actual_err"
        printf '  expected_stdout=%q\n' "$expected"
    fi
}

finite_args=(
    '0' '1' '-1' '+2' '003' '-004' '5/2' '-7/3'
    '10/20' '001/004' '12/5' '-9/6' '14/7' '123/10' '-50/25' '8/3'
    '99/11' '-18/12' '+42/6' '0007/0008'
)
finite_nums=(0 1 -1 2 3 -4 5 -7 10 1 12 -9 14 123 -50 8 99 -18 42 7)
finite_dens=(1 1 1 1 1 1 2 3 20 4 5 6 7 10 25 3 11 12 6 8)

for i in "${!finite_args[@]}"; do
    for step in 0 1 2 3 4 5 6 7; do
        j=$(( (i + 3 * step + 1) % ${#finite_args[@]} ))
        run_case "${finite_args[$i]}" "${finite_args[$j]}" \
            "${finite_nums[$i]}" "${finite_dens[$i]}" \
            "${finite_nums[$j]}" "${finite_dens[$j]}"
    done
done

run_case '100/250' '30/40' 100 250 30 40
run_case '-100/250' '30/40' -100 250 30 40
run_case '999/27' '-333/9' 999 27 -333 9
run_case '64/16' '32/8' 64 16 32 8
run_case '81/27' '-3' 81 27 -3 1
run_case '-81/27' '3' -81 27 3 1
run_case '7/13' '11/13' 7 13 11 13
run_case '-7/13' '11/13' -7 13 11 13
run_case '12345/5' '-2345' 12345 5 -2345 1
run_case '-12345/5' '2345' -12345 5 2345 1
run_case '1/999' '998/999' 1 999 998 999
run_case '-1/999' '-998/999' -1 999 -998 999
run_case '333/111' '222/111' 333 111 222 111
run_case '333/111' '-222/111' 333 111 -222 111
run_case '17/31' '19/37' 17 31 19 37
run_case '-17/31' '19/37' -17 31 19 37
run_case '0/7' '9/11' 0 7 9 11
run_case '0/7' '-9/11' 0 7 -9 11
run_case '0000005' '0000006' 5 1 6 1
run_case '-0000005' '+0000006' -5 1 6 1

run_case '4/5' '3/0' 4 5 3 0
run_case '1' '3/0' 1 1 3 0
run_case '-2' '5/0' -2 1 5 0
run_case '0/7' '2/0' 0 7 2 0
run_case '100/3' '1/0' 100 3 1 0
run_case '-9/4' '8/0' -9 4 8 0
run_case '5/0' '4' 5 0 4 1
run_case '7/0' '-3' 7 0 -3 1

run_case '1/3' '-8/0' 1 3 -8 0
run_case '2' '-3/0' 2 1 -3 0
run_case '5/6' '-1/0' 5 6 -1 0
run_case '-5/6' '-1/0' -5 6 -1 0
run_case '-7/0' '3' -7 0 3 1
run_case '-9/0' '-3' -9 0 -3 1

run_case '3/0' '4/0' 3 0 4 0
run_case '-3/0' '4/0' -3 0 4 0
run_case '0/0' '1' 0 0 1 1
run_case '1' '0/0' 1 1 0 0
run_case '0/0' '0/0' 0 0 0 0
run_case '000/000' '4' 0 0 4 1

if (( total != 200 )); then
    printf 'FAIL: generated %d cases, expected 200\n' "$total"
    exit 1
fi

printf 'TOTAL=%d FAILED=%d\n' "$total" "$failed"
exit "$failed"
