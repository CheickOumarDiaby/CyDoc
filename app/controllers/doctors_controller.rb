class DoctorsController < ApplicationController
  # GET /patients
  def index
    query = params[:query]
    query ||= params[:search][:query] if params[:search]
    query ||= params[:quick_search][:query] if params[:quick_search]

    @doctors = Doctor.clever_find(query)
    respond_to do |format|
      format.html {
        render :action => 'list'
        return
      }
      format.js {
        render :update do |page|
          page.replace_html 'search_results', :partial => 'list'
        end
      }
    end
  end

  def search
    query = params[:query] || params[:search][:query]
    query ||= params[:search][:query] if params[:search]
    @doctors = Doctor.clever_find(query)

    render :partial => 'list', :layout => false
  end

  def show
    @doctor = Doctor.find(params[:id])
    @account = @doctor.account
  end

  # GET /posts/new
  def new
    doctor = params[:doctor]
    @doctor = Doctor.new(doctor)
    @doctor.build_account(params[:accounting_bank_account])
    @doctor.build_vcard(params[:vcard])
  end

  def create
    @doctor = Doctor.new(params[:doctor])
    @doctor.build_account(params[:accounting_bank_account])
    @doctor.build_vcard(params[:vcard])

    if @doctor.save
      flash[:notice] = 'Arzt gespeichert.'
      redirect_to @doctor
    else
      render :action => :new
    end
  end

  def edit
    @doctor = Doctor.find(params[:id])
    @account = @doctor.account
    render :action => 'edit'
  end
  
  def update
    @doctor = Doctor.find(params[:id])

    @doctor.build_account unless @doctor.account
    @doctor.build_vcard unless @doctor.vcard

    if @doctor.update_attributes(params[:doctor]) && @doctor.account.update_attributes(params[:accounting_bank_account]) && @doctor.vcard.update_attributes(params[:vcard])
      flash[:notice] = 'Arzt gespeichert.'
      redirect_to :action => :show, :id => @doctor
    else
      render :action => :new
    end
  end
end
