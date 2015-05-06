# encoding: UTF-8

class Case < ActiveRecord::Base
  belongs_to :classification
  belongs_to :patient
  belongs_to :doctor
  belongs_to :insurance
  belongs_to :session

  def to_s
    "#{patient.to_s}: PAP Abstrich #{praxistar_eingangsnr}"
  end

  def create_treatment(provider)
    puts self.praxistar_eingangsnr

    # Law
    law = Law.new(:code => 'LawKvg', :insured_id => patient.insurance_policies.by_policy_type('KVG').first.number)

    # Treatment
    treatment = patient.treatments.build(
      :date_begin => examination_date,
      :date_end   => examination_date,
      :canton     => 'ZH',
      :reason     => 'Krankheit',
      :law        => law,
      :referrer   => doctor
    )

    # Session
    session = treatment.sessions.build(
      :duration_from => examination_date,
      :duration_to   => examination_date,
      :treatment     => treatment
    )

    if classification
      # TariffItem
      tariff_code = "#{classification.name} (#{classification.examination_method.name})"
      tariff_item = TariffItem.clever_find(tariff_code).first

      raise "Tarif für code '#{classification.name} (#{classification.examination_method.name})' nicht gefunden" unless tariff_item

      # Service Records
      session.build_service_record(tariff_item)
    end

    # Save record
    if treatment.save
      self.session = session
      self.save

      return nil
    else
      logger.info("[Error] Failed to create treatment for case #{self.praxistar_eingangsnr}:")
      logger.info(treatment.errors.full_messages.join("\n"))

      return self
    end

    treatment
  end

  named_scope :no_treatment, :conditions => ["session_id IS NULL"]
  named_scope :finished, :conditions => ["screened_at IS NOT NULL AND (needs_review = ? OR review_at IS NOT NULL)", false]
  named_scope :finished_at, proc {|date|
    {
      :conditions => ["screened_at < :date AND (needs_review = :false OR review_at < :date)", {:date => date, :false => false}]
    }
  }

  def self.create_all_treatments
    doctor = Doctor.find_by_code(Thread.current["doctor_id"])
    date = DateTime.now.ago(doctor.settings['cases.invoice_grace_period'])

    failed_cases = []

    cases = self.finished_at(date).no_treatment
    for a_case in cases
      failed_cases << a_case.create_treatment(doctor)
    end

    return cases.count, failed_cases.compact!
  end
end
