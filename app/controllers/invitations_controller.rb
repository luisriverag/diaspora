#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class InvitationsController < Devise::InvitationsController

  before_filter :check_token, :only => [:edit] 


  def create
      if current_user.invites == 0
        flash[:error] = I18n.t 'invitations.create.no_more'
        redirect_to :back
        return
      end
    begin
      params[:user][:aspect_id] = params[:user].delete(:aspects)
      message = params[:user].delete(:invite_messages)
      params[:user][:invite_message] = message unless message == ""

      emails = params[:user][:email].split(/, */)
      invited_users = emails.map { |e| current_user.invite_user(params[:user].merge({:email => e}))}
      good_users, rejected_users = invited_users.partition {|u| u.persisted? }

      flash[:notice] = I18n.t('invitations.create.sent') + good_users.map{|x| x.email}.join(', ')
      if rejected_users.any?
        flash[:error] = I18n.t('invitations.create.rejected') + rejected_users.map{|x| x.email}.join(', ')
      end
    rescue RuntimeError => e
      if  e.message == "You have no invites"
        flash[:error] = I18n.t 'invitations.create.no_more'
      elsif e.message == "You already invited this person"
        flash[:error] = I18n.t('invitations.create.already_sent', :gender => current_user)
      elsif e.message == "You are already connected to this person"
        flash[:error] = I18n.t('invitations.create.already_contacts', :gender => current_user)
      else
        raise e
      end
    end
    redirect_to :back 
  end

  def update
    begin
      user = User.find_by_invitation_token(params[:user][:invitation_token])
      user.seed_aspects
      user.accept_invitation!(params[:user])
    rescue MongoMapper::DocumentNotValid => e
      user = nil
      flash[:error] = e.message
    end
    if user
      flash[:notice] = I18n.t 'registrations.create.success'
      sign_in_and_redirect(:user, user)
    else
      redirect_to accept_user_invitation_path(
        :invitation_token => params[:user][:invitation_token])
    end
  end

  protected

  def check_token
    if User.find_by_invitation_token(params[:invitation_token]).nil?
      flash[:error] = I18n.t 'invitations.check_token.not_found'
      redirect_to root_url
    end
  end
end
