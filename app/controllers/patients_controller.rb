# encoding: UTF-8
class PatientsController < ApplicationController
  in_place_edit_for :vcard, :family_name
  in_place_edit_for :vcard, :given_name
  in_place_edit_for :vcard, :extended_address
  in_place_edit_for :vcard, :street_address
  in_place_edit_for :vcard, :post_office_box
  in_place_edit_for :vcard, :postal_code
  in_place_edit_for :vcard, :locality
  in_place_edit_for :patient, :birth_date
  in_place_edit_for :patient, :remarks
  in_place_edit_for :patient, :insurance_nr

  in_place_edit_for :phone_number, :phone_number_type
  in_place_edit_for :phone_number, :number

  in_place_edit_for :session, :date
  # TODO: is duplicated in ServiceRecordsController
  in_place_edit_for :service_record, :ref_code
  in_place_edit_for :service_record, :quantity

  in_place_edit_for :invoice, :due_date

  respond_to :js, :only => :covercard_search

  def localities_for_postal_code
    render :update do |page|
      localities = PostalCode.find_all_by_zip(params[:postal_code])
      if localities.count == 1
        page.replace 'patient_vcard_attributes_locality', text_field_tag('patient[vcard_attributes][locality]', localities[0].locality)
      elsif localities.count > 1
        page.replace 'patient_vcard_attributes_locality', select('patient[vcard_attributes]', 'locality', localities.collect {|p| p.locality })
      end
      page.call 'focus', 'patient_vcard_attributes_locality'
    end
  end

  def postal_codes_for_locality
    render :update do |page|
      postal_codes = PostalCode.find(:all, :conditions => ["locality LIKE CONCAT('%', ?, '%')", params[:locality]])
      if postal_codes.count == 1
        page.replace 'patient_vcard_attributes_postal_code', text_field_tag('patient[vcard_attributes][postal_code]', postal_codes[0].zip, :size => 9)
      elsif postal_codes.count > 1
        page.replace 'patient_vcard_attributes_postal_code', select('patient[vcard_attributes]', 'postal_code', postal_codes.collect {|p| ["#{p.zip} - #{p.locality}", p.zip] })
      end
      page.call 'focus', 'patient_vcard_attributes_postal_code'
    end
  end

  # Covercard
  # =========

  # Checks if the patient has new covercard infomations.
  # Returns a flash message when new infomations available.
  def covercard_check_update
    # TODO: Implement an AJAX Request when a patient is loaded to do this action and of course this action.
    @patient = Patient.find(params[:id])
  end

  def covercard_update
    @patient = Patient.find(params[:id])
    @covercard_patient = Covercard::Patient.find(params[:covercard_code])
    @patient, @updated_attributes, @updated_insurance_policies = @covercard_patient.update(@patient)
  end

  def covercard_search
    @covercard_patient = Covercard::Patient.find(params[:code])

    if @covercard_patient
      @exact_patients = Patient.by_date(@covercard_patient.birth_date).by_name(@covercard_patient.name)
      @date_patients = Patient.by_date(@covercard_patient.birth_date)
      @name_patients = Patient.by_name(@covercard_patient.name)
    end
  end

  # GET /patients
  def index
    query = params[:query]
    query ||= params[:search][:query] if params[:search]
    query ||= params[:quick_search][:query] if params[:quick_search]

    if query.present?
      @patients, query_type, covercard_code = Patient.clever_find(query, :page => params[:page])

      @suggest_covercard_search = covercard_code if query_type == 'covercard'
      # Show selection list only if more than one hit
      return if !params[:all] && redirect_if_match(@patients)
    else
      @patients = Patient.paginate(:page => params['page'], :order => 'vcards.family_name, vcards.given_name')
    end

    respond_to do |format|
      format.html {
        render :action => 'list'
      }
      format.js {
        render :update do |page|
          page.replace_html 'search_results', :partial => 'list'
        end
      }
    end
  end

  def search
    query = params[:query] || params[:search]
    query ||= params[:search][:query] if params[:search]
    query ||= params[:quick_search][:query] if params[:quick_search]
    @patients = Patient.clever_find(query)

    render :partial => 'list', :layout => false
  end

  # GET /patients/new
  def new
    if params[:patient] && params[:patient][:from_covercard].present?
      params[:patient].delete(:from_covercard)
      params[:patient]['insurance_policies_attributes'].delete('1')
      @patient = Patient.new(params[:patient])
      @patient.insurance_policies << InsurancePolicy.new(:policy_type => 'UVG')
    else
      @patient = Patient.new(params[:patient])
      @patient.build_vcard unless @patient.vcard

      # Use default sex from doctor settings
      case Doctor.settings['patients.sex']
      when 'M'
        @patient.sex = 'M'
        @patient.vcard.honorific_prefix = 'Herr'
      when 'F'
        @patient.sex = 'F'
        @patient.vcard.honorific_prefix = 'Frau'
      end
    end

    @patient.doctor_patient_nr = Patient.maximum('CAST(doctor_patient_nr AS UNSIGNED INTEGER)').to_i + 1
  end

  # POST /patients
  def create
    @patient = Patient.new

    if @patient.update_attributes(params[:patient])
      flash[:notice] = 'Patient erfasst.'
      redirect_to @patient
    else
      render :action => :new
    end
  end

  # GET /patients/1/edit
  def edit
    @patient = Patient.find(params[:id])

    respond_to do |format|
      format.html {}
      format.js {
        render :update do |page|
          page.replace_html "tab-content-personal", :partial => 'edit'
          page.call(:addDatePickerBehaviour)
        end
      }
    end
  end

  # PUT /patients/1
  def update
    @patient = Patient.find(params[:id])

    respond_to do |format|
      if @patient.update_attributes(params[:patient])
        flash[:notice] = 'Patient wurde geändert.'
        format.html { redirect_to(@patient) }
        format.js {
          render :update do |page|
            page.replace_html "tab-content-personal", :partial => 'show'
          end
        }
      else
        format.html { render :action => "edit" }
        format.js {
          render :update do |page|
            page.replace_html "tab-content-personal", :partial => 'edit'
          end
        }
      end
    end
  end

  # GET /patients/1
  def show
    @patient = Patient.find(params[:id])

    respond_to do |format|
      format.html { }
      format.js {
        render :update do |page|
          page.replace_html "tab-content-personal", :partial => 'show'
        end
      }
    end
  end

  # GET /patients/1/show_tab
  def show_tab
    respond_to do |format|
      @patient = Patient.find(params[:id])

      format.js {
        # For partial updates used in form cancellation events
        if tab = params[:tab]
          render :update do |page|
            page.replace "patient-#{tab}", :partial => tab
          end
        end
      }
    end
  end

  # DELETE /patient/1
  def destroy
    @patient = Patient.find(params[:id])

    @patient.destroy

    respond_to do |format|
      format.html {
        redirect_to patients_path
      }
      format.js {
        render :update do |page|
          page.redirect_to patients_path
        end
      }
    end
  end

  # POST /patients/1/print_label
  print_action_for :label, :tray => :label, :media => 'Label'
  def label
    @patient = Patient.find(params[:id])

    respond_to do |format|
      format.html {}
      format.pdf { render_pdf(:media => 'Label') }
    end
  end

  # POST /patients/1/print_full_label
  print_action_for :full_label, :tray => :label, :media => 'Label'
  def full_label
    @patient = Patient.find(params[:id])

    respond_to do |format|
      format.html {}
      format.pdf { render_pdf(:media => 'Label') }
    end
  end
end
