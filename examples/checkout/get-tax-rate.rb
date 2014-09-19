require_relative '../base'

module Examples
  module Checkout
    class Walkthrough
      def self.run(client)

        # Create the order step by step:
        # You may also choose to start it off with some line items
        # See checkout/creating_with_line_items.rb
        response = client.post('/api/orders')

        if response.status == 201
          client.succeeded "Created new checkout."
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

        response = client.post("/api/orders/#{order['number']}/line_items",
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
        response = client.put("/api/checkouts/#{order['number']}/next")
        if response.status == 200
          order = JSON.parse(response.body)
          client.succeeded "Transitioned order into address state."
        else
          client.failed "Could not transition order to address state."
        end

        # Add address information to the order
        # Before you make this request, you may need to make a request to one or both of:
        # - /api/countries
        # - /api/states
        # This will give you the correct country_id and state_id params to use for address information.

        # First, get the country:
        response = client.get('/api/countries?q[name_cont]=United States')
        if response.status == 200
          client.succeeded "Retrieved a list of countries."
          countries = JSON.parse(response.body)['countries']
          usa = countries.first
          if usa['name'] != 'United States'
            client.failed "Expected first country to be 'United States', but it wasn't."
          end
        else
          client.failed "Failed to retrieve a list of countries."
        end

        # Then, get the state we want from the states of that country:

        response = client.get("/api/countries/#{usa['id']}/states?q[name_cont]=Minnesota")
        if response.status == 200
          client.succeeded "Retrieved a list of states."
          states = JSON.parse(response.body)['states']
          minnesota = states.first
          if minnesota['name'] != 'Minnesota'
            client.failed "Expected first state to be 'Minnesota', but it wasn't."
          end
        else
          client.failed "Failed to retrieve a list of states."
        end

        # We can finally submit some address information now that we have it all:
        address = {
          first_name: 'Test',
          last_name: 'User',
          address1: '5 County Rd B E',
          address2: '',
          country_id: usa['id'],
          state_id: minnesota['id'],
          city: 'Little Canada',
          zipcode: '55117',
          phone: '(555) 555-5555'
        }

        response = client.put("/api/checkouts/#{order['number']}",
          {
            order: {
              bill_address_attributes: address,
              ship_address_attributes: address
            }
          }
        )

        if response.status == 200
          client.succeeded "Address details added."
          order = JSON.parse(response.body)
          if (order['tax_total'].to_f > 0)
            client.succeeded "Taxes has been calculated."
          else
            client.failed "Taxes could not be calculated."
          end
        else
          client.failed "Could not add address details to order."
        end

      end
    end
  end
end

Examples.run(Examples::Checkout::Walkthrough)