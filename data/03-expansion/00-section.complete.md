## Variable Expansion & Parameter Substitution

This section defines when and how to use braces in variable expansion, following a simplicity-first principle. The default form is `"$var"` without braces, reserving braces (`"${var}"`) only for cases where they're syntactically required: parameter expansion operations (`${var##pattern}`, `${var:-default}`), variable concatenation (`"${var1}${var2}"`), array expansions (`"${array[@]}"`), and disambiguation. This approach keeps code cleaner and more readable while avoiding unnecessary syntax.
