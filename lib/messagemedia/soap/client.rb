require 'savon'

require_relative 'message'

module Messagemedia
  module SOAP

    SOAP_ENDPOINT = 'https://soap.m4u.com.au/?wsdl'

    #
    # This class is a light-weight wrapper around the MessageMedia SOAP API.
    #
    class Client

      #
      # Initialize the SOAP client.
      #
      # Your MessageMedia username and password must be provided.
      #
      # These credentials will not be authenticated until an actual request
      # is made using one of the other methods available in this class.
      #
      def initialize(username, password, debug = false)
        # Store the credentials for use with other methods
        @credentials = {
            :'api:userId' => username,
            :'api:password' => password
        }

        # Create a new Savon-based SOAP client
        @client = Savon.client(wsdl: SOAP_ENDPOINT, log: debug)
      end

      #
      # Send a message to a recipient.
      #
      # A destination number (destination_number) is required.
      #
      # The source number (source_number), message content (content), and
      # message identifier (messageId) are optional. Optional arguments
      # may be omitted by providing nil as an argument.
      #
      # If a message identifier is provided, then it will be returned as
      # part of any replies or delivery reports produced as a result of
      # this message.
      #
      # If a source number is not provided, the message will be sent using
      # the MessageMedia rotary.
      #
      def send_message(destination_number, content, message_id = nil, source_number: nil, delivery_report: true)

        # Construct a Message object to represent the message
        message = Message.new
        message.content = content
        message.delivery_report = delivery_report
        message.format = FORMAT_SMS
        message.validity_period = 1
        message.origin = source_number
        message.add_recipient(message_id, destination_number)

        messages = {
            :'@sendMode' => "normal",
            :'api:message' => [message.to_api_hash]
        }

        body = {
            :'api:authentication' => @credentials,
            :'api:requestBody' => {:'api:messages' => messages}
        }

        # Make a request to the MessageMedia SOAP service. Note that the
        # message parameter below refers to the body of the SOAP request,
        # not the message object that we constructed above.
        response = @client.call(:send_messages, message: body)

        response.body[:send_messages_response][:result]
      end

      #
      # Send multiple messages using a single request.
      #
      # An array of Message objects must be provided. Unlike the send_message
      # method, this method requires the Message objects to be constructed
      # manually.
      #
      # Constructing an instance of Message is straight-forward:
      #   message = Message.new
      #   message.content = <message content>
      #   message.delivery_report = <true|false>
      #   message.format = <FORMAT_SMS|FORMAT_VOICE>
      #   message.validity_period = 1
      #   message.origin = <source_number>
      #   message.add_recipient(<message ID>, <destination number>)
      #
      def send_messages(messages)
        messages = {
            :'@sendMode' => 'normal',
            :'api:message' => messages.map { |m| m.to_api_hash }
        }

        body = {
            :'api:authentication' => @credentials,
            :'api:requestBody' => {:'api:messages' => messages}
        }
        response = @client.call(:send_messages, message: body)

        response.body[:send_messages_response][:result]
      end

      #
      # Retrieve the credit info and other metadata that is available for
      # a MessageMedia account.
      #
      def get_user_info
        body = {
            :'api:authentication' => @credentials
        }

        response = @client.call(:check_user, message: body)

        response.body[:check_user_response][:result]
      end

      #
      # Check for, and return, the replies that are available.
      #
      # A maximum number of replies (max_replies) may be specified, in order
      # to limit the size of the response.
      #
      # Note that the same replies will be returned by subsequent calls to
      # this method, unless you also call confirm_replies to confirm that
      # the replies have been received.
      #
      def check_replies(max_replies = nil)
        body = {
            :'api:authentication' => @credentials,
            :'api:requestBody' => {}
        }

        unless max_replies.nil?
          body[:'api:requestBody'][:'api:maxReplies'] = max_replies
        end

        response = @client.call(:check_replies, message: body).body[:check_replies_response][:result]
        if response[:replies]
          response[:replies] = response[:replies][:reply]
        else
          response[:replies] = []
        end

        response
      end

      #
      # Confirm that replies have been received.
      #
      # An array of reply IDs (reply_ids) must be provided. Each of the IDs
      # in this array should correspond to a reply that was received using
      # the check_replies method.
      #
      def confirm_replies(reply_ids)
        body = {
            :'api:authentication' => @credentials,
            :'api:requestBody' => {
                :'api:replies' => {
                    :'api:reply' => reply_ids.map do |reply_id|
                      {:'@receiptId' => reply_id}
                    end
                }
            }
        }

        response = @client.call(:confirm_replies, message: body)

        response.body[:confirm_replies_response][:result][:'@confirmed']
      end

      #
      # Check for, and return, the Delivery Reports that are available.
      #
      # A maximum number of reports (max_reports) may be specified, in order
      # to limit the size of the response.
      #
      # Note that the same delivery reports will be returned by subsequent
      # calls to this method, unless you also call confirm_replies to confirm
      # that the replies have been received.
      #
      # Note also that Delivery Reports are often called Delivery Receipts,
      # and the terms can be used interchangeably.
      #
      def check_reports(max_reports = nil)
        body = {
            :'api:authentication' => @credentials,
            :'api:requestBody' => {}
        }

        unless max_reports.nil?
          body[:'api:requestBody'][:'api:maxReports'] = max_reports
        end

        response = @client.call(:check_reports, message: body).body[:check_reports_response][:result]
        if response[:reports]
          response[:reports] = response[:reports][:report]
        else
          response[:reports] = []
        end

        response
      end

      #
      # Confirm that Delivery Reports have been received.
      #
      # An array of delivery report IDs (report_ids) must be provided. Each
      # of the IDs in this array should correspond to a Delivery Report that
      # was received using the check_reports method.
      #
      def confirm_reports(report_ids)
        body = {
            :'api:authentication' => @credentials,
            :'api:requestBody' => {
                :'api:reports' => {
                    :'api:report' => report_ids.map do |report_id|
                      {:'@receiptId' => report_id}
                    end
                }
            }
        }

        response = @client.call(:confirm_reports, message: body)

        response.body[:confirm_reports_response][:result][:'@confirmed']
      end

      #
      # Return a list of blocked numbers.
      #
      # The number of returned items can be restricted using (max_recipients).
      #
      def get_blocked_numbers(max_recipients = nil)
        body = {
            :'api:authentication' => @credentials,
            :'api:requestBody' => {}
        }
        unless max_recipients.nil?
          body[:'api:requestBody'][:'api:maximumRecipients'] = max_recipients
        end

        response = @client.call(:get_blocked_numbers, message: body).body[:get_blocked_numbers_response][:result]
        if response[:recipients]
          response[:recipients] = response[:recipients][:recipient]
        else
          response[:recipients] = []
        end

        response
      end

      #
      # Add numbers to the blocked list
      #
      # An array of numbers must be provided in (numbers).
      #
      def block_numbers(numbers)
        body = create_recipients_body numbers

        response = @client.call(:block_numbers, message: body)

        response.body[:block_numbers_response][:result]
      end

      #
      # Remove numbers from the blocked list.
      #
      # An array of numbers must be provided in (numbers).
      # The numbers in this list must correspond to a number previously blocked
      # using the block_numbers method.
      #
      def unblock_numbers(numbers)
        body = create_recipients_body numbers

        response = @client.call(:unblock_numbers, message: body)

        response.body[:unblock_numbers_response][:result]
      end

      #
      # Delete scheduled messages.
      #
      # An array of message ids must be provided in (message_ids).
      # The ids in this array must correspond to messages previously sent
      # using the send_messages method, where a scheduled date was set.
      #
      def delete_scheduled_messages(message_ids)
        # body = {
        #     :'api:authentication' => @credentials,
        #     :'api:requestBody' => {
        #         :'api:messages' => {
        #             :'api:message' => message_ids.map do |id|
        #               {:'@messageId' => id}
        #             end
        #         }
        #     }
        # }
        body = {
            :'api:authentication' => @credentials,
            :'api:requestBody' => {
                :'api:messages' =>
                    message_ids.map do |id|
                      {:'api:message' => {:'@messageId' => id}}
                    end
            }
        }

        response = @client.call(:delete_scheduled_messages, message: body)
        response.body[:delete_scheduled_messages_response][:result]
      end

      def create_recipients_body(numbers)
        {
            :'api:authentication' => @credentials,
            :'api:requestBody' => {
                :'api:recipients' => {
                    :'api:recipient' => numbers.each { |n| n }
                }
            }
        }
      end
    end
  end
end