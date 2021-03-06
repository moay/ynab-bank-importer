class Dumper
  # Implements logic to fetch transactions via the Fints protocol
  # and implements methods that convert the response to meaningful data.
  class Fints < Dumper
    require 'ruby_fints'
    require 'digest/md5'

    def initialize(params = {})
      @ynab_id  = params.fetch('ynab_id')
      @username = params.fetch('username').to_s
      @password = params.fetch('password').to_s
      @iban     = params.fetch('iban')
      @endpoint = params.fetch('fints_endpoint')
      @blz      = params.fetch('fints_blz')
    end

    def fetch_transactions
      FinTS::Client.logger.level = Logger::WARN
      client = FinTS::PinTanClient.new(@blz, @username, @password, @endpoint)

      account = client.get_sepa_accounts.find { |a| a[:iban] == @iban }
      statement = client.get_statement(account, Date.today - 35, Date.today)

      statement.map { |t| to_ynab_transaction(t) }
    end

    private

    def account_id
      @ynab_id
    end

    def date(transaction)
      transaction.entry_date || transaction.date
    end

    def payee_name(transaction)
      transaction.name.try(:strip)
    end

    def payee_iban(transaction)
      transaction.iban
    end

    def memo(transaction)
      [
        transaction.description,
        transaction.information
      ].compact.join(' / ').try(:strip)
    end

    def amount(transaction)
      (transaction.amount * transaction.sign * 1000).to_i
    end

    def withdrawal?(transaction)
      memo = memo(transaction)
      return nil unless memo

      memo.include?('Atm') || memo.include?('Bargeld')
    end

    def import_id(transaction)
      Digest::MD5.hexdigest(transaction.source)
    end
  end
end
