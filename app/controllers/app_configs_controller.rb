class AppConfigsController < ApplicationController
  def edit
    unless current_user.is_superuser?
      flash[:error] = "You do not have the authority to edit application-wide settings."
      redirect_to root_path
    end
    @app_config = AppConfig.find(params[:id])
    @selected_auth_types = @app_config.auth_types.split(', ')
  end
  
  def update
    @app_config = AppConfig.find(params[:id])
    if @app_config.update_attributes(params[:app_config])
      flash[:notice] = "Successfully updated appconfig."
    end
    @selected_auth_types = @app_config.auth_types.split(', ')
    render :action => 'edit'
  end
end
