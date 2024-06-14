# Update customer metadata in stripe

## Summary

This DAG updates the delete_by and status customer's metadata fields. This DAG is executed daily at 05:00 UTC.

## Permissions and keys

- **Stipe API key:**  This process need to read several objects from stripe, for this scenario we use the **STRIPE_FULL** key.

## Main function

The main funcion is calles update_customer_status, this function calls stripe_get_data to get all the customers ans subscriptions data.

Once all the data is retrieved, the main function iterates over all the customers executing find_subs_info.

The find_subs_info functions checks for all the subscriptions of the actual customers, chacks it's statuses and finile writes the fields in stripe acording to the next scenarios:

- **All subscriptions canceled:** Sets the status as canceled and the delete_by field as the must recent canceled_at date plus 93 days.

- **At lease one subscription is not canceled:** Sets the status as the status of the not canceled subscription and the delete_by as empty.
