module StripeMock
  module RequestHandlers
    module Helpers

      def get_card(object, card_id, class_name='Customer')
        customer_or_charge = (object[:object] == 'customer' || object[:object] == 'charge') ? true : false
        card_or_source = customer_or_charge ? 'source' : 'card'
        param = customer_or_charge ? 'id' : 'card'
        card = object[:"#{card_or_source}s"][:data].find{|cc| cc[:id] == card_id }
        if card.nil?
          msg = customer_or_charge ? "There is no source with ID #{card_id}." : "Recipient #{object[:id]} does not have a card with ID #{card_id}"
          raise Stripe::InvalidRequestError.new(msg, param, 404)
        end
        card
      end

      def add_card_to_object(type, card, object, replace_current=false)
        card[type] = object[:id]
        card_or_source = (type == :customer || type == :charge) ? 'source' : 'card'

        if replace_current
          object[:"#{card_or_source}s"][:data].delete_if {|card| card[:id] == object[:"default_#{card_or_source}"]}
          object[:"default_#{card_or_source}"] = card[:id]
        else
          object[:"#{card_or_source}s"][:total_count] += 1
        end

        object[:"default_#{card_or_source}"] = card[:id] unless object[:"default_#{card_or_source}"]
        object[:"#{card_or_source}s"][:data] << card

        card
      end

      def retrieve_object_cards(type, type_id, objects)
        resource = assert_existence type, type_id, objects[type_id]
        card_or_source = (type == :customer || objects[:object] == :charge) ? 'source' : 'card'
        sources = resource[:"#{card_or_source}s"]

        Data.mock_list_object(sources[:data])
      end

      def delete_card_from(type, type_id, card_id, objects)
        resource = assert_existence type, type_id, objects[type_id]
        card_or_source = (type == :customer || objects[:object] == :charge) ? 'source' : 'card'

        assert_existence :card, card_id, get_card(resource, card_id)

        card = { id: card_id, deleted: true }
        resource[:"#{card_or_source}s"][:data].reject!{|cc|
          cc[:id] == card[:id]
        }
        resource[:"default_#{card_or_source}"] = resource[:"#{card_or_source}s"][:data].count > 0 ? resource[:"#{card_or_source}s"][:data].first[:id] : nil
        card
      end

      def add_card_to(type, type_id, params, objects)
        resource = assert_existence type, type_id, objects[type_id]

        card = card_from_params(params[:card])
        add_card_to_object(type, card, resource)
      end

      def validate_card(card)
        [:exp_month, :exp_year].each do |field|
          card[field] = card[field].to_i
        end
        card
      end

      def card_from_params(attrs_or_token)
        if attrs_or_token.is_a? Hash
          attrs_or_token = generate_card_token(attrs_or_token)
        end
        card = get_card_by_token(attrs_or_token)
        validate_card(card)
      end

    end
  end
end
