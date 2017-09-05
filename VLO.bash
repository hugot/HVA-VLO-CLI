#!/bin/bash

dotDir="$HOME/.VLO"
sessionTime="$dotDir/sessionTime"
url="https://vlo.informatica.hva.nl"
cookie="$dotDir/cham.cookie"
username="default"

[[ -d $dotDir ]] || mkdir $dotDir

notLoggedIn(){
  if [[ -f $sessionTime ]]; then
    if [[ $(cat $sessionTime) -lt $(($(date +'%s') - 360000)) ]]; then
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

case $1 in
  courses)
    echo $'\t ==== COURSES ===='
    curl -s -X GET --cookie $cookie $url/user_portal.php | \
      grep -i 'class="row"' -A 3 | grep -io --perl-regexp '(?<=alt=")[^"]*' |\
      while read line; do ((lineno++)); [[ $lineno -gt 1 ]] && echo "$line"; done
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
esac

