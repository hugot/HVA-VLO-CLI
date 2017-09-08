#!/bin/bash

dotDir="$HOME/.VLO"
sessionTime="$dotDir/sessionTime"
url="https://vlo.informatica.hva.nl"
cookie="$dotDir/cham.cookie"
username="default" 
defaultCompletrionString='exit ls searchcourse'
[[ -d $dotDir ]] || mkdir $dotDir

notLoggedIn(){
  if [[ -f $sessionTime ]]; then
    if [[ $(cat $sessionTime) -lt $(($(date +'%s') - 3600)) ]]; then
      return 0
    else return 1
    fi
  else
    curl -s -X GET --cookie $cookie $url/user_portal.php |\
      grep -i 'You are not allowed to see this page' >/dev/null
  fi
}

login(){
  if [[ "$username" == 'default' ]]; then
    read -p 'Enter username:' username
  fi
  read -s -p 'Enter password:' password
  echo
  loggedIn(){
    curl -s --cookie $cookie -X GET $url/index.php |\
      grep 'id="user_image_block"' >/dev/null
  }
  curl -s --cookie-jar $cookie -X POST -F 'login=thunnih001' \
    -F "password=$password" $url/index.php | grep -i 'id="user_image_block"'
  while ! loggedIn; do
    read -s -p 'The password was icorrect, please enter the correct password:' password
    echo
    curl -s --cookie-jar $cookie -X POST -F 'login=thunnih001' \
      -F "password=$password" $url/index.php | grep -i 'id="user_image_block"'
  done
  date +'%s' > $sessionTime
}

queryString(){
    while getopts 'f:v:' o; do
      case $o in
        f)
          field="$OPTARG"
          getopts 'v:f:' e
          case $e in
            v)
              value="$OPTARG"
              queryString="$queryString&${field}=${value}"
              ;;
            *)
              echo Error: function: queryString: no value was assigned for one of the fields
              exit 199
          esac
          ;;
        v)
          echo Error: function: queryString: a value without fieldname predefined has been found
          exit 199
          ;;
      esac
    done
  echo "${queryString/&}"
}

if notLoggedIn; then 
  login
else 
  date +'%s' > $sessionTime
fi


execute(){
  case $1 in
    ls)
      lineno=0
      courseList=()
      locList=()
      declare -A locList
      echo $'\t ==== COURSES ===='
      shopt -s lastpipe
      curl -s -X GET --cookie $cookie $url/user_portal.php | \
        grep -i 'class="row"' -A 3 | grep -io --perl-regexp '(?<=/courses/)[^/]+|(?<=alt=")[^"]*' |\
        while read line; do 
          ((lineno++))
          if [[ $lineno -gt 1 ]] ; then
            if [[ $(($lineno%2)) -eq 1 ]]; then 
              line="${line// /-}"
              courseList[${#courseList[@]}]="$line"
              echo "$line"
            else
              locList[${#locList[@]}]="$line"
            fi
          fi
        done
        ;;
      searchcourse)
        shift
        echo $'\t==== SEARCH RESULTS ===='
        sec_token="$(curl -s -X GET --cookie $cookie "$url/main/auth/courses.php" |\
          grep -o --perl-regex '(?<=name="sec_token" value=")[^"]*')"
        query="$(queryString -f action -v subscribe \
          -f category_code -v ALL \
          -f hidden_links -v "" \
          -f pageCurrent -v 1 \
          -f pageLength -v 12 \
          -f search_term -v "" \
          -f search_course -v 1 \
          -f sec_token -v "$sec_token" )"
        curl -s -X POST --cookie $cookie "$url/main/auth/courses.php" \
          -F "sec_token=$sec_token" -F 'search_course=1' -F "search_term=$1" |\
          grep --perl-regex -io '(?<=<h4 class="title">)[^<]*'
        ;;
      cd)
        shift
        case "$location/${1/$location/}" in
          '~'/*/*/*)
            echo 'course/group|global/directory'
            ;;
          '~'/*/*)
            echo course/group or course/global
            ;;
          '~'/*)
            echo course
            ;;
          *)
            echo "$location/${1/$location/}"
        esac
        ;;
      exit)
        break
        ;;
    esac
}

tabComplete(){
  lastSpace=0
  for i in `seq 1 ${#READLINE_LINE}`; do
    [[ ${READLINE_LINE:$i:1} == ' ' && $lastSpace -eq 0 ]] && firstSpace=$i
    [[ ${READLINE_LINE:$i:1} == ' ' ]] && lastSpace=$i
  done
  case ${READLINE_LINE:0:$(($firstSpace))} in
    cd)
      completionString="${courseList[*]}"
      ;;
    *)
      completionString="$defaultCompletrionString"
  esac
  if [[ $lastSpace -eq 0 ]]; then
    word="$READLINE_LINE"
  else 
    word="${READLINE_LINE:$(($lastSpace+1))}"
  fi
  result=($(compgen -W "$completionString" "$word"))
  [[ $word == '' ]] && echo "${result[@]}" && return 0
  if [[ ${#result[@]} -eq 1 ]]; then
    if [[ $lastSpace -eq 0  ]]; then
      READLINE_LINE="${result[0]}"
    else
      READLINE_LINE="${READLINE_LINE:0:$(($lastSpace+1))}${result[0]}"
    fi
    READLINE_POINT=${#READLINE_LINE}
  else
    local lastMatchedChar=${#result[1]}
    for i in `seq 0 $((${#result[@]}-1))`; do
      for n in `seq 0 $((${#result[@]}-1))`; do
        for x in `seq 0 $((${#result[$i]}-1))`; do
          if [[ ${result[$i]:$x:1} != ${result[$n]:$x:1} ]] && [[ "${result[$n]}" != "${result[$i]}" ]]; then
            [[ $lastMatchedChar -gt $x ]] && lastMatchedChar=$x
            break
          fi
        done
      done
    done
    if [[ $lastMatchedChar -gt 0 ]]; then
      READLINE_LINE="${READLINE_LINE:0:$(($lastSpace+1))}${result[0]:0:$lastMatchedChar}"
    else
      READLINE_LINE="${READLINE_LINE}"
    fi
    READLINE_POINT=${#READLINE_LINE}
    echo "${result[@]}"
  fi
}

set -o emacs
bind -x '"\t":"tabComplete"'
location="~"

echo -e '\n\t===== HVA VLO CLI 1.0 ====='
execute ls >/dev/null
completionString="$defaultCompletrionString"
while read -e -p "$location/:" cmd; do
  execute $cmd
  completionString='exit ls searchcourse'
done

# code to load a list of the global files of a course.
#heey='false'
#curl -s -X GET --cookie $cookie $url/main/document/document.php?cidReq=DATASTRUCTURES |\
#  while read line; do 
#    if [[ $line =~ '>Type</a>' ]]; then 
#      heey='true'
#    elif $heey; then 
#      [[ $line =~ '</table>' ]] && heey='false'
#      echo $line 
#    fi
#  done | grep -o --perl-regexp '(?<=title=")[^"]*' | sort -u --ignore-case | sed '/^.*\(cidReq\|Download\).*$/d'

