let rec dir_scanner procedure accumulator target =
  if Sys.is_directory target then begin
    let entries = Sys.readdir target in
    Sys.chdir target;
    let accumulator = Array.fold_left (dir_scanner procedure) accumulator entries in
    Sys.chdir "..";
    accumulator
  end else begin
    let file_desc = open_in_bin target in
    let rec loop accumulator =
     match try Some (input_line file_desc) with End_of_file -> None with
       Some line -> loop (procedure accumulator line)
     | None -> accumulator in
    loop accumulator
  end
  
  
