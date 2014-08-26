require_relative '../base'
require 'braintree'
require 'yaml'

module Examples
  module Checkout
    class WalkthroughWithExistingCreditCard
      def self.run(client)
        braintree_config_file = File.dirname(__FILE__) + "/braintree.yml"
        unless File.exists?(braintree_config_file)
          client.pending "braintree.yml does not exist. Cannot proceed."
          exit
        end

        # Create the order step by step:
        # You may also choose to start it off with some line items
        # See checkout/creating_with_line_items.rb
        response = client.post('/api/orders')

        if response.status == 201
          orderNumber = JSON.parse(response.body)["number"]
          client.succeeded "Created new checkout: " + orderNumber
          order = JSON.parse(response.body)
          if order['email'] == 'spree@example.com'
            # Email addresses are necessary for orders to transition to address.
            # This just makes really sure that the email is already set.
            # You will not have to do this in your own API unless you've customized it.
            client.succeeded 'Email set automatically on order successfully.'
          else
            client.failed %Q{
              Email address was not automatically set on order.'
              -> This may lead to problems transitioning to the address step.
            }
          end
        else
          client.failed 'Failed to create a new blank checkout.'
        end

        # Assign a line item to the order we just created.

        response = client.post("/api/orders/#{orderNumber}/line_items",
        {
          line_item: {
            variant_id: 1,
            quantity: 1
          }
        }
        )


        if response.status == 201
          client.succeeded "Added a line item."
        else
          client.failed "Failed to add a line item."
        end

        # Transition the order to the 'address' state
        response = client.put("/api/checkouts/#{orderNumber}/next")
        if response.status == 200
          order = JSON.parse(response.body)
          client.succeeded "Transitioned order into address state."
        else
          client.failed "Could not transition order to address state."
        end

        # Add address information to the order

        address = {
          first_name: 'Test',
          last_name: 'User',
          address1: 'Unit 1',
          address2: '1 Test Lane',
          country_id: 49,
          state_id: 26,
          city: 'Bethesda',
          zipcode: '20814',
          phone: '(555) 555-5555'
        }

        response = client.put("/api/checkouts/#{orderNumber}",
        {
          order: {
            bill_address_attributes: address,
            ship_address_attributes: address
          }
        })

        if response.status == 200
          client.succeeded "Address details added."
          order = JSON.parse(response.body)
          if order['state'] == 'delivery'
            client.succeeded "Order automatically transitioned to 'delivery'."
          else
            client.failed "Order failed to automatically transition to 'delivery'."
          end
        else
          client.failed "Could not add address details to order."
        end

        # Next step: delivery!

        first_shipment = order['shipments'].first
        response = client.put("/api/checkouts/#{orderNumber}",
        {
          order: {
            shipments_attributes: [
              id: first_shipment['id'],
              selected_shipping_rate_id: first_shipment['shipping_rates'].first['id']
            ]
          }
        }
        )

        if response.status == 200
          client.succeeded "Delivery options selected."
          order = JSON.parse(response.body)
          if order['state'] == 'payment'
            client.succeeded "Order automatically transitioned to 'payment'."
          else
            client.failed "Order failed to automatically transition to 'payment'."
          end
        else
          client.failed "The store was not happy with the selected delivery options."
        end

        # Next step: payment!

        # Find the braintree payment method:
        braintree_payment_method = order['payment_methods'].detect { |pm| pm['name'] == "Braintree" }
        if !braintree_payment_method
          client.failed "Braintree payment method not found."
        end

        # Invalid credit card number

        response = client.put("/api/checkouts/#{orderNumber}",
        {
          order: {
            payments_attributes: [{
              payment_method_id: braintree_payment_method['id']
            }],
          },
          payment_source: {
            braintree_payment_method['id'] => {
              number: '1',
              month: '1',
              year: '2017',
              verification_value: '123',
              name: 'John Smith',
            }
          }
        })

        if response.status == 422
          order = JSON.parse(response.body)
          puts order
          if order.to_s != '{"exception"=>"Credit card type is not accepted by this merchant account. (81703) Credit card number must be 12-19 digits. (81716)"}'
            client.failed "Incorrect error received"
          end
        else
          client.failed "Error expected"
        end

        # Expired credit card

        response = client.put("/api/checkouts/#{orderNumber}",
        {
          order: {
            payments_attributes: [{
              payment_method_id: braintree_payment_method['id']
            }],
          },
          payment_source: {
            braintree_payment_method['id'] => {
              number: '4111111111111111',
              month: '1',
              year: '2000',
              verification_value: '123',
              name: 'John Smith',
            }
          },
          state: 'payment'
        })

        if response.status == 422
          order = JSON.parse(response.body)
          puts order
          if order.to_s != '{"error"=>"Invalid resource. Please fix errors and try again.", "errors"=>{"payments.Credit Card"=>[" Card has expired"]}}'
            client.failed "Incorrect error received"
          end
        else
          client.failed "Error expected"
        end

        # AVS Postal Code does not match

        address = {
          first_name: 'Test',
          last_name: 'User',
          address1: 'Unit 1',
          address2: '1 Test Lane',
          country_id: 49,
          state_id: 26,
          city: 'Bethesda',
          zipcode: '20000',
          phone: '(555) 555-5555'
        }

        response = client.put("/api/checkouts/#{orderNumber}",
        {
          order: {
            bill_address_attributes: address,
            ship_address_attributes: address
          },
          state: 'address'
        })

        if response.status == 200
          client.succeeded "Address details added."
          order = JSON.parse(response.body)
          if order['state'] == 'delivery'
            client.succeeded "Order automatically transitioned to 'delivery'."
          else
            client.failed "Order failed to automatically transition to 'delivery'."
          end
        else
          client.failed "Could not add address details to order."
        end

        # Next step: delivery!

        first_shipment = order['shipments'].first
        response = client.put("/api/checkouts/#{orderNumber}",
        {
          order: {
            shipments_attributes: [
              id: first_shipment['id'],
              selected_shipping_rate_id: first_shipment['shipping_rates'].first['id']
            ]
          }
        }
        )

        if response.status == 200
          client.succeeded "Delivery options selected."
          order = JSON.parse(response.body)
          if order['state'] == 'payment'
            client.succeeded "Order automatically transitioned to 'payment'."
          else
            client.failed "Order failed to automatically transition to 'payment'."
          end
        else
          client.failed "The store was not happy with the selected delivery options."
        end

        response = client.put("/api/checkouts/#{orderNumber}",
        {
          order: {
            payments_attributes: [{
              payment_method_id: braintree_payment_method['id']
            }],
          },
          payment_source: {
            braintree_payment_method['id'] => {
              number: '4111111111111111',
              month: '1',
              year: '2017',
              verification_value: '123',
              name: 'John Smith',
            }
          },
          state: 'payment'
        })

        if response.status == 422
          order = JSON.parse(response.body)
          puts order
          if order.to_s != '{"exception"=>"Processor declined: Approved (1000)"}'
            client.failed "Incorrect error received"
          end
        else
          client.failed "Error expected"
        end
      end
    end
  end
end

Examples.run(Examples::Checkout::WalkthroughWithExistingCreditCard)