#load "str.cma";;

(* Input part *)

let invalid_pat = "\\(\\..*\\)\\|\\(.*~\\)\\|\\(#.*\\)"
let invalid_exp = Str.regexp invalid_pat

let rec dir_scanner procedure accumulator target =
  if Str.string_match invalid_exp target 0 then accumulator else begin
  if Sys.is_directory target then begin
    let entries = Sys.readdir target in
    let pwd = Sys.getcwd () in
    Sys.chdir target;
    let accumulator = Array.fold_left (dir_scanner procedure) accumulator entries in
    Sys.chdir pwd;
    accumulator
  end else begin
    let file_desc = open_in_bin target in
    let rec loop accumulator =
      match try Some (input_line file_desc) with End_of_file -> None with
        Some line -> loop (procedure accumulator line)
      | None -> accumulator in
    let accumulator = loop accumulator in
    close_in file_desc;
    accumulator
  end
  end

(** Configuration *)
let default_book = "Wallet" 
let default_book_for_spending = "Expense" 
let default_book_for_income = "Income"

type date = {year : int; month : int; day : int}
let date_exp = Str.regexp "\\([0-9][0-9][0-9][0-9]\\)-\\([0-9][0-9]\\)-\\([0-9][0-9]\\)"

let day_of_month_table = [|31; -1; 31; 30; 31; 30; 31; 31; 30; 31; 30; 31|] 
let day_of_month year month = 
  if month < 1 || month > 12 then -1 else
  if month = 2 then
    if ( year mod 4 ) == 0 && ( year mod 100 ) != 0 || ( year mod 400 ) == 0 then 29 else
    28
  else day_of_month_table.(month - 1)

let date_of string = 
  if Str.string_match date_exp string 0 then
    let year = int_of_string (Str.matched_group 1 string) in
    let month = int_of_string (Str.matched_group 2 string) in
    let day = int_of_string (Str.matched_group 3 string) in
    if month < 0 || month > 12 then None else
    if day < 0 || day > day_of_month year month then None else
    Some {year = year; month = month; day}
  else
    None

let string_of_date date = Printf.sprintf "%04d-%02d-%02d" date.year date.month date.day

type transaction = 
    {date : date;
     source : string;
     target : string;
     kind : string;
     comment : string;
     amount : int}

let create_transaction date source target kind comment amount = 
  {date = date; source = source; target = target; kind = kind; comment = comment;
   amount = amount}

let read_transaction_income =
  let pattern = 
    "^\\[\\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\\)\\]\\$\\$[ \t]+\\([^ \t]+\\)[ \t]+\\([^ \t].+[^ \t][ \t]+\\)?\\([0-9]+\\)$" in
  let exp = Str.regexp pattern in
  fun line ->
    if Str.string_match exp line 0 then
    let date = Str.matched_group 1 line in
    let kind = Str.matched_group 2 line in
    let comment = try Str.matched_group 3 line with Not_found -> "" in
    let amount = int_of_string (Str.matched_group 4 line) in
    match date_of date with
      Some date -> 
        Some (create_transaction date default_book_for_income default_book kind comment amount)
    | None -> None
  else None
        

let read_transaction_spending =
  let pattern = 
    "^\\[\\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\\)\\]\\$[ \t]+\\([^ \t]+\\)[ \t]+\\([^ \t].+[^ \t][ \t]+\\)?\\([0-9]+\\)$" in
  let exp = Str.regexp pattern in 
  fun line -> 
    if Str.string_match exp line 0 then
    let date = Str.matched_group 1 line in
    let kind = Str.matched_group 2 line in
    let comment = try Str.matched_group 3 line with Not_found -> "" in
    let amount = int_of_string (Str.matched_group 4 line) in
    match date_of date with
      Some date -> 
        Some (create_transaction date default_book default_book_for_spending kind comment amount)
    | None -> None
    else None
    

let read_transaction =
  let pattern = 
    "^\\[\\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\\)\\]\\$[ \t]+\\([^ \t]+\\) -> \\([^ \t]+\\)[ \t]+\\([^ \t]+\\)[ \t]+\\([^ \t].+[^ \t][ \t]+\\)?\\([0-9]+\\)$" in
  let exp = Str.regexp pattern in 
  fun line ->
    if Str.string_match exp line 0 then
    let date = Str.matched_group 1 line in
    let source = Str.matched_group 2 line in
    let target = Str.matched_group 3 line in
    let kind = Str.matched_group 4 line in
    let comment = try Str.matched_group 5 line with Not_found -> "" in
    let amount = int_of_string (Str.matched_group 6 line) in
    match date_of date with
      Some date -> Some (create_transaction date source target kind comment amount)
    | None -> None
    else None

let read_entry line = 
  let income = read_transaction_income line in
  let spending = read_transaction_spending line in
  let transaction = read_transaction line in
  match income, spending, transaction with
    _, _, Some transaction -> Some transaction
  | Some income, _, _ -> Some income
  | _, Some spending, _ -> Some spending
  | _, _ ,_ -> None

type account = 
    {name : string;
     unit_value : float;
     transactions_in : transaction list;
     transactions_out : transaction list}

let create_account name unit_value = {name = name; unit_value = unit_value; 
                                      transactions_in = []; transactions_out = []}
type ledger = account list

let find_account name ledger =
  try List.find (fun account -> account.name = name) ledger, ledger with
    Not_found -> 
      let new_account = create_account name 1.0 in
      new_account, (new_account :: ledger)

let add_transaction_to_account transaction account = 
  if transaction.source = account.name then
    {account with transactions_out = transaction :: account.transactions_out}
  else if transaction.target = account.name then
    {account with transactions_in = transaction :: account.transactions_in}
  else account

let update_account account ledger =
  let other_accounts = List.filter (fun a -> a.name <> account.name) ledger in
  account :: other_accounts

let register_transaction ledger line =
  match read_entry line with
    None -> ledger
  | Some transaction ->
      let source, ledger = find_account transaction.source ledger in
      let target, ledger = find_account transaction.target ledger in
      let source = add_transaction_to_account transaction source in
      let target = add_transaction_to_account transaction target in
      let ledger = update_account source ledger in
      update_account target ledger 

let read_books target = 
 dir_scanner register_transaction [] target

(* create report*) 

type report = {from_date : date;
               to_date : date;
               transactions : transaction list;
               sum_in : int;
               sum_out : int;
               balance : int;
               kind_sum_in : (string * int) list;
               kind_sum_out : (string * int) list;
              }

let date_leq date1 date2 =
  (date1.year < date2.year) ||
    (date1.year = date2.year) && (date1.month < date2.month) ||
    (date1.year = date2.year) && (date1.month = date2.month) && (date1.day <= date2.day)

let compare_date date1 date2 =
  if date1 = date2 then 0 else
  if date_leq date1 date2 then ~-1 else 1 

let sum transactions = List.fold_left (fun s t -> s + t.amount) 0 transactions 

let kind_sum transactions =
  let for_each sums t =
    let sum = (try List.assoc t.kind sums with Not_found -> 0) + t.amount in
    (t.kind, sum) :: List.remove_assoc t.kind sums in
  List.fold_left for_each [] transactions

let create_report account date1 date2  =
  let transactions_in = 
    List.filter (fun t -> date_leq date1 t.date && date_leq t.date date2)
      account.transactions_in in
  let transactions_out = 
    List.filter (fun t -> date_leq date1 t.date && date_leq t.date date2)
      account.transactions_out in
  let compare t1 t2 = compare_date t1.date t2.date in
  let transactions = List.sort compare (transactions_in @ transactions_out) in
  let sum_in = sum transactions_in in
  let sum_out = sum transactions_out in
  let balance = sum_in - sum_out in
  let kind_sum_in = kind_sum transactions_in in
  let kind_sum_out = kind_sum transactions_out in
  {from_date = date1;
   to_date = date2;
   transactions = transactions;
   sum_in = sum_in;
   sum_out = sum_out;
   balance = balance;
   kind_sum_in = kind_sum_in;
   kind_sum_out = kind_sum_out}

let print_transaction trans =
  Printf.printf "%s\t%s\t->\t%s\t%s\t%s\t%d\n"
    (string_of_date trans.date)
    trans.source
    trans.target
    trans.kind
    trans.comment
    trans.amount

let print_report report =
  Printf.printf "From %s to %s:\n" (string_of_date report.from_date) (string_of_date report.to_date);
  Printf.printf "----------------------All Transactions----------------------\n";
  List.iter print_transaction report.transactions;
  Printf.printf "---------------------------End------------------------------\n";
  Printf.printf "Income:\t%d\n" report.sum_in;
  Printf.printf "Expense:\t%d\n" report.sum_out;
  Printf.printf  "----------------------Income Breakdown----------------------\n";
  List.iter (function kind, sum -> Printf.printf "%s\t%d\n" kind sum) report.kind_sum_in;
  Printf.printf  "----------------------Expense Breakdown---------------------\n";
  List.iter (function kind, sum -> Printf.printf "%s\t%d\n" kind sum) report.kind_sum_out;
  Printf.printf  "------------------------------------------------------------\n"

 
let dir = ref "."

let speclist = [
  "-d", Arg.Set_string dir, "Root directory for accounting data";
]

let argv = Array.make 3 ""
let argc = ref 0

let anon_fun s =
  if !argc > 2 then raise (Arg.Bad "Too many arguments") else begin
    argv.(!argc) <- s;
    incr argc
  end

let () = Arg.parse speclist anon_fun 
  "Usage: moh -d DIRECTORY ACCOUNT FROM(YEAR-MONTH-DATE) TO(YEAR-MONTH-DATE)"

let ledger = read_books !dir

let report = 
  let account, _ = find_account argv.(0) ledger in
  let from_date = 
    match date_of argv.(1) with 
      Some d -> d 
    | None -> failwith (Printf.sprintf "Invalid argument %s" argv.(1)) in
  let to_date = 
    match date_of argv.(2) with 
      Some d -> d 
    | None -> failwith (Printf.sprintf "Invalid argument %s" argv.(2)) in
  create_report account from_date to_date

let () = print_report report

