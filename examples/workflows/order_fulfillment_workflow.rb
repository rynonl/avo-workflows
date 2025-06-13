# frozen_string_literal: true

# Example: E-commerce Order Fulfillment Workflow
# Manages the complete order lifecycle from placement to delivery
class OrderFulfillmentWorkflow < Avo::Workflows::Base
  step :pending_payment do
    action :payment_received, to: :processing
    action :payment_failed, to: :payment_failed
    action :cancel_order, to: :cancelled
  end

  step :payment_failed do
    action :retry_payment, to: :pending_payment
    action :cancel_order, to: :cancelled
  end

  step :processing do
    action :items_reserved, to: :preparing_shipment
    action :out_of_stock, to: :backordered
    action :cancel_order, to: :cancelled
  end

  step :backordered do
    action :items_available, to: :processing
    action :partial_shipment, to: :preparing_shipment
    action :cancel_order, to: :cancelled
  end

  step :preparing_shipment do
    action :ready_to_ship, to: :shipped
    action :packaging_issue, to: :processing
  end

  step :shipped do
    action :delivered, to: :delivered
    action :delivery_failed, to: :delivery_failed
    action :return_requested, to: :return_initiated
  end

  step :delivery_failed do
    action :retry_delivery, to: :shipped
    action :return_to_sender, to: :returned
  end

  step :delivered do
    action :return_requested, to: :return_initiated
    action :confirm_delivery, to: :completed
  end

  step :return_initiated do
    action :return_received, to: :returned
    action :return_cancelled, to: :delivered
  end

  step :returned do
    action :refund_processed, to: :refunded
    action :exchange_processed, to: :processing
  end

  step :refunded do
    # Final state
  end

  step :completed do
    # Final state
  end

  step :cancelled do
    action :refund_processed, to: :refunded
  end

  # Example usage with conditions based on context
  # step :processing do
  #   condition { context[:inventory_available] == true }
  # end

  # step :preparing_shipment do
  #   condition { context[:payment_verified] == true }
  # end
end