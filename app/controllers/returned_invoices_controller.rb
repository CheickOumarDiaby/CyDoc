class ReturnedInvoicesController < ApplicationController
  # Inherited Resources
  inherit_resources

  # Scopes
  has_scope :by_doctor_id
  has_scope :by_state

  public
  def index
    params[:by_state] = 'ready' if params[:by_state].blank?

    @returned_invoices = apply_scopes(ReturnedInvoice)
  end

  def create
    create! do |success, failure|
      success.html {
        @returned_invoice.patient.update_attribute(:dunning_stop, true)
        flash[:notice] = @returned_invoice.to_s
        redirect_to new_returned_invoice_path
      }
    end
  end

  def update
    @returned_invoice = ReturnedInvoice.find(params[:id])

    @patient = @returned_invoice.patient
    unless @patient.update_attributes(params[:patient]) and @returned_invoice.update_attributes(params[:returned_invoice])
      render 'edit' and return
    end

    # Remember previous state to redirect to this list
    previous_state = @returned_invoice.state

    case params[:commit]
    when 'queue_request'
      queue_request
      return
    when 'reactivate'
      reactivate
      return
    when 'write_off'
      write_off
      return
    else
    end

    redirect_to returned_invoices_path(:by_state => previous_state)
  end

  def reactivate
    @returned_invoice = ReturnedInvoice.find(params[:id])

    # Remember previous state to redirect to this list
    previous_state = @returned_invoice.state

    @treatment = @returned_invoice.invoice.treatment
    @patient = @treatment.patient
    @old_invoice = @returned_invoice.invoice

    # Saving
    if @old_invoice.valid?
      @returned_invoice.invoice.reactivate.save
      @returned_invoice.patient.update_attribute(:dunning_stop, false)

      @invoice = Invoice.create_from_treatment(@treatment, Date.today, "TiersGarant", Doctor.find(Thread.current["doctor_id"]), Doctor.find(Thread.current["doctor_id"]))
      if @invoice.print(@printers[:trays][:plain], @printers[:trays][:invoice])
        flash[:notice] = 'Neue Rechnung an Drucker gesendet.'
        @invoice.state = 'printed'
        @invoice.save!

        @returned_invoice.reactivate!
        redirect_to returned_invoices_path(:by_state => previous_state) and return
      else
        flash[:error] = 'Rechnung konnte nicht gedruckt werden.'
      end
    end

    respond_to do |format|
      format.html { render 'edit' }
      format.js {
        page.replace_html "error_flash", flash[:error]
        page.show "error_flash"
      }
    end
  end

  def write_off
    @returned_invoice = ReturnedInvoice.find(params[:id])

    # Remember previous state to redirect to this list
    previous_state = @returned_invoice.state

    @returned_invoice.invoice.write_off.save
    @returned_invoice.patient.update_attribute(:dunning_stop, false)
    @returned_invoice.write_off!

    redirect_to returned_invoices_path(:by_state => previous_state)
  end

  def queue_request
    @returned_invoice = ReturnedInvoice.find(params[:id])

    # Remember previous state to redirect to this list
    previous_state = @returned_invoice.state

    @returned_invoice.queue_request!

    redirect_to returned_invoices_path(:by_state => previous_state)
  end

  def queue_all_requests
    doctor = Doctor.find(params[:doctor_id])
    doctor.request_all_returned_invoices

    redirect_to returned_invoices_path
  end

  # PDF
  def request_document
    doctor = Doctor.find(params[:doctor_id])

    respond_to do |format|
      format.html {}
      format.pdf {
        document = doctor.document_to_pdf(:returned_invoice_request, :sender => @current_doctor)

        send_data document, :filename => "#{doctor.id}.pdf",
                            :type => "application/pdf",
                            :disposition => 'inline'
      }
    end
  end

  def print_request_document
    doctor = Doctor.find(params[:doctor_id])

    doctor.print_document(:returned_invoice_request, @printers[:trays][:plain], :sender => @current_doctor)
    doctor.request_all_returned_invoices

    redirect_to returned_invoices_path
  end
end
