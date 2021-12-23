class WebhooksController < ApplicationController
  # disable CSRF checking
  skip_before_action :verify_authenticity_token

  def create
    # receive POST from Stripe or another third party
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']
    event = nil

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )
    rescue JSON::ParserError => e
      # Invalid payload
      render json: {message: e}, status: 400
      return
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      render json: {message: e}, status: 400
      return
    end

    # Handle the event
    case event.type
    when 'checkout.session.completed'
      checkout_session = event.data.object 
      Order.create(status: checkout_session.payment_status user_id: current_or_guest_user.id stripe_id: checkout_session.stripe_id)
      puts 'Checkout session was successful!'
    when 'payment_method.attached'
      payment_method = event.data.object # contains a Stripe::PaymentMethod
      puts 'PaymentMethod was attached to a Customer!'
      # ... handle other event types
    else
      puts "Unhandled event type: #{event.type}"
    end

    render json: { message: 'success' }
  end
end