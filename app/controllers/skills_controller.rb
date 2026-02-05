class SkillsController < ApplicationController
  # keep require_login enabled; optionally restrict create/update/destroy later

  def index
    skills = Skill.where(is_active: true).order(:level, :name)
    render json: skills
  end

  def show
    render json: Skill.find(params[:id])
  end

  def create
    skill = Skill.new(skill_params)
    if skill.save
      render json: skill, status: :created
    else
      render json: { errors: skill.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    skill = Skill.find(params[:id])
    if skill.update(skill_params)
      render json: skill
    else
      render json: { errors: skill.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    Skill.find(params[:id]).destroy
    head :no_content
  end

  private

  def skill_params
    params.require(:skill).permit(:name, :level, :description, :is_active)
  end
end
