#include "../fa2/fa2_tzip16_interface.mligo"

type global_token_id =
{
  fa2: address;
  token_id: token_id;
}

type token =
[@layout:comb]
{
 token_for_sale_address: address;
 token_for_sale_token_id: token_id;
}

type sale =
[@layout:comb]
{
  price: tez; // assume in mutez?
  token: token;
}

type storage = (sale, address) big_map

type market_entry_points =
  | Sell of sale
  | Buy of sale
  | Cancel of sale

let transfer_nft(fa2_address, token_id, from, to_: address * token_id * address * address): operation =
  let fa2_transfer : ((transfer list) contract) option =
      Tezos.get_entrypoint_opt "%transfer"  fa2_address in
  let transfer_op = match fa2_transfer with
  | None -> (failwith "CANNOT_INVOKE_FA2_TRANSFER" : operation)
  | Some c ->
    let tx = {
      from_ = from;
      txs= [{
        to_ = to_;
        token_id = token_id;
        amount = 1n;
    }]} in
    Tezos.transaction [tx] 0mutez c in
  transfer_op

let add_operator_nft(fa2_address, token_id, from, to_: address * token_id * address * address): operation =
  let fa2_update_operator : ((update_operator list) contract) option =
    Tezos.get_entrypoint_opt "%update_operators" fa2_address in
  let update_operator_op = match fa2_update_operator with
    | None -> (failwith "CANNOT_INVOKE_FA2_UPDATE_OPERATOR" : operation)
    | Some c ->
       let tx = Add_operator ( { owner = to_; operator = from; token_id = token_id; } ) in
       Tezos.transaction [tx] 0mutez c in
  update_operator_op


let remove_operator_nft(fa2_address, token_id, operator, owner: address * token_id * address * address): operation =
  let fa2_update_operator : ((update_operator list) contract) option =
    Tezos.get_entrypoint_opt "%update_operators" fa2_address in
  let update_operator_op = match fa2_update_operator with
    | None -> (failwith "CANNOT_INVOKE_FA2_UPDATE_OPERATOR" : operation)
    | Some c ->
       let tx = Remove_operator ( { owner = owner; operator = operator; token_id = token_id; } ) in
       Tezos.transaction [tx] 0mutez c in
  update_operator_op

let transfer_money(fa2_address, token_id, amount_, from, to_: address * token_id * nat * address * address): operation =
  let fa2_transfer : ((transfer list) contract) option =
      Tezos.get_entrypoint_opt "%transfer"  fa2_address in
  let transfer_op = match fa2_transfer with
  | None -> (failwith "CANNOT_INVOKE_MONEY_FA2" : operation)
  | Some c ->
    let tx = {
      from_ = from;
      txs= [{
        to_ = to_;
        token_id = token_id;
        amount = amount_;
    }]} in
    Tezos.transaction [tx] 0mutez c
 in transfer_op


let transfer_tez (price, buyer, seller : tez * address * address) : operation list =
  let buyer_account = match (Tezos.get_contract_opt buyer : unit contract option) with
    | None -> (failwith "NO_BUYER_ACCOUNT" : unit contract)
    | Some acc -> acc
  in let seller_account = match (Tezos.get_contract_opt seller : unit contract option) with
    | None -> (failwith "NO_SELLER_ACCOUNT" : unit contract)
    | Some acc -> acc
     in let debit_op = Tezos.transaction () (0tz - price) buyer_account in
        let credit_op = Tezos.transaction () price seller_account in
        (debit_op :: credit_op :: [])

let buy_token(sale, storage: sale * storage) : (operation list * storage) =
  let seller = match Big_map.find_opt sale storage with
  | None -> (failwith "NO_SALE": address)
  | Some s -> s
  in
  let tx_money_ops = transfer_tez(sale.price, Tezos.sender, seller) in
  let tx_nft_op = transfer_nft(sale.token.token_for_sale_address, sale.token.token_for_sale_token_id, Tezos.self_address, Tezos.sender) in
  let tx_nft_remove_operator_op = remove_operator_nft(sale.token.token_for_sale_address, sale.token.token_for_sale_token_id, Tezos.self_address, Tezos.sender) in
  let new_s = Big_map.remove sale storage in
  (tx_nft_remove_operator_op :: tx_nft_op :: tx_money_ops), new_s

let deposit_for_sale(sale, storage: sale * storage) : (operation list * storage) =
    let transfer_op =
      transfer_nft (sale.token.token_for_sale_address, sale.token.token_for_sale_token_id, Tezos.sender, Tezos.self_address) in
    let add_operator_op = add_operator_nft (sale.token.token_for_sale_address, sale.token.token_for_sale_token_id, Tezos.self_address, Tezos.sender) in
    let new_s = Big_map.add sale Tezos.sender storage in
    (add_operator_op :: transfer_op :: []), new_s

let cancel_sale(sale, storage: sale * storage) : (operation list * storage) = match Big_map.find_opt sale storage with
    | None -> (failwith "NO_SALE" : (operation list * storage))
    | Some owner -> if owner = Tezos.sender then
                      let tx_nft_back_op = transfer_nft(sale.token.token_for_sale_address, sale.token.token_for_sale_token_id, Tezos.self_address, Tezos.sender) in
                      let remove_operator_op =
                        remove_operator_nft(sale.token.token_for_sale_address,sale.token.token_for_sale_token_id,Tezos.self_address,Tezos.sender)
                      in
                      (tx_nft_back_op :: remove_operator_op :: []), Big_map.remove sale storage
      else (failwith "NOT_OWNER": (operation list * storage))

let main (p, storage : market_entry_points * storage) : operation list * storage = match p with
  | Sell sale -> deposit_for_sale(sale, storage)
  | Buy sale -> buy_token(sale, storage)
  | Cancel sale -> cancel_sale(sale,storage)
