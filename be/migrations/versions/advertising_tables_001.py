"""Create advertising tables

Revision ID: advertising_001
Revises: country001
Create Date: 2026-01-07

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'advertising_001'
down_revision = 'country001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create region_pricing table first (referenced by subscriptions)
    op.create_table(
        'region_pricing',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('region_code', sa.String(2), nullable=False),
        sa.Column('currency', sa.String(3), nullable=False),
        sa.Column('master_monthly', sa.Numeric(10, 2), nullable=False),
        sa.Column('master_annual', sa.Numeric(10, 2), nullable=False),
        sa.Column('vip_monthly', sa.Numeric(10, 2), nullable=False),
        sa.Column('vip_annual', sa.Numeric(10, 2), nullable=False),
        sa.Column('regular_commission', sa.Numeric(5, 4), nullable=False),
        sa.Column('master_commission', sa.Numeric(5, 4), nullable=False),
        sa.Column('vip_commission', sa.Numeric(5, 4), nullable=False),
        sa.Column('featured_cph', sa.Numeric(10, 2), nullable=False),
        sa.Column('search_cpc_min', sa.Numeric(10, 2), nullable=False),
        sa.Column('search_cpc_max', sa.Numeric(10, 2), nullable=False),
        sa.Column('map_cph', sa.Numeric(10, 2), nullable=False),
        sa.Column('boost_cpm', sa.Numeric(10, 2), nullable=False),
        sa.Column('master_credits', postgresql.JSON(astext_type=sa.Text()), nullable=False),
        sa.Column('vip_credits', postgresql.JSON(astext_type=sa.Text()), nullable=False),
        sa.Column('default_tax_rate', sa.Numeric(5, 4), server_default='0'),
        sa.Column('tax_included', sa.Boolean(), server_default='false'),
        sa.Column('effective_date', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True)),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_region_pricing_region_code', 'region_pricing', ['region_code'], unique=True)
    
    # Seed Brazil pricing
    op.execute("""
        INSERT INTO region_pricing (
            region_code, currency,
            master_monthly, master_annual, vip_monthly, vip_annual,
            regular_commission, master_commission, vip_commission,
            featured_cph, search_cpc_min, search_cpc_max, map_cph, boost_cpm,
            master_credits, vip_credits,
            default_tax_rate, tax_included, effective_date
        ) VALUES (
            'BR', 'BRL',
            249.00, 2490.00, 749.00, 7490.00,
            0.1500, 0.1200, 0.0800,
            15.00, 0.30, 0.75, 25.00, 8.00,
            '{"featured_hours": 4, "search_clicks": 200, "map_hours": 2, "boost_impressions": 5000}',
            '{"featured_hours": 12, "search_clicks": 1000, "map_hours": 8, "boost_impressions": 25000}',
            0.0000, false, NOW()
        )
    """)
    
    # Create advertising_subscriptions table
    op.create_table(
        'advertising_subscriptions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('tier', sa.String(20), nullable=False, server_default='regular'),
        sa.Column('status', sa.String(20), nullable=False, server_default='active'),
        sa.Column('region_code', sa.String(2), nullable=False, server_default='BR'),
        sa.Column('monthly_fee', sa.Numeric(10, 2), server_default='0'),
        sa.Column('commission_rate', sa.Numeric(5, 4), nullable=False),
        sa.Column('credits', postgresql.JSON(astext_type=sa.Text())),
        sa.Column('billing_cycle_start', sa.DateTime(timezone=True)),
        sa.Column('next_billing_date', sa.DateTime(timezone=True)),
        sa.Column('payment_method_id', sa.String(100)),
        sa.Column('created_at', sa.DateTime(timezone=True)),
        sa.Column('updated_at', sa.DateTime(timezone=True)),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_advertising_subscriptions_bar_id', 'advertising_subscriptions', ['bar_id'], unique=True)
    op.create_index('idx_subscription_tier_status', 'advertising_subscriptions', ['tier', 'status'])
    op.create_index('idx_subscription_next_billing', 'advertising_subscriptions', ['next_billing_date'])
    
    # Create advertising_campaigns table
    op.create_table(
        'advertising_campaigns',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('subscription_id', sa.Integer(), nullable=False),
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('campaign_type', sa.String(20), nullable=False),
        sa.Column('status', sa.String(20), nullable=False, server_default='draft'),
        sa.Column('budget_type', sa.String(20), nullable=False),
        sa.Column('budget_amount', sa.Numeric(10, 2), nullable=False),
        sa.Column('budget_spent', sa.Numeric(10, 2), server_default='0'),
        sa.Column('start_time', sa.DateTime(timezone=True), nullable=False),
        sa.Column('end_time', sa.DateTime(timezone=True)),
        sa.Column('targeting', postgresql.JSON(astext_type=sa.Text())),
        sa.Column('creative', postgresql.JSON(astext_type=sa.Text())),
        sa.Column('impressions', sa.Integer(), server_default='0'),
        sa.Column('clicks', sa.Integer(), server_default='0'),
        sa.Column('conversions', sa.Integer(), server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True)),
        sa.Column('updated_at', sa.DateTime(timezone=True)),
        sa.ForeignKeyConstraint(['subscription_id'], ['advertising_subscriptions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_advertising_campaigns_id', 'advertising_campaigns', ['id'])
    op.create_index('ix_advertising_campaigns_bar_id', 'advertising_campaigns', ['bar_id'])
    op.create_index('idx_campaign_bar_status', 'advertising_campaigns', ['bar_id', 'status'])
    op.create_index('idx_campaign_type_status', 'advertising_campaigns', ['campaign_type', 'status'])
    op.create_index('idx_campaign_schedule', 'advertising_campaigns', ['start_time', 'end_time'])
    
    # Create advertising_impressions table
    op.create_table(
        'advertising_impressions',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('campaign_id', sa.Integer(), nullable=False),
        sa.Column('action', sa.String(20), nullable=False),
        sa.Column('placement', sa.String(50), nullable=False),
        sa.Column('user_id', sa.Integer()),
        sa.Column('session_id', sa.String(100)),
        sa.Column('latitude', sa.Numeric(9, 6)),
        sa.Column('longitude', sa.Numeric(9, 6)),
        sa.Column('ip_hash', sa.String(64)),
        sa.Column('user_agent', sa.String(255)),
        sa.Column('timestamp', sa.DateTime(timezone=True)),
        sa.ForeignKeyConstraint(['campaign_id'], ['advertising_campaigns.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_advertising_impressions_campaign_id', 'advertising_impressions', ['campaign_id'])
    op.create_index('idx_impression_campaign_action', 'advertising_impressions', ['campaign_id', 'action'])
    op.create_index('idx_impression_timestamp', 'advertising_impressions', ['timestamp'])
    op.create_index('idx_impression_user_campaign', 'advertising_impressions', ['user_id', 'campaign_id'])
    
    # Create advertising_invoices table
    op.create_table(
        'advertising_invoices',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('period_start', sa.DateTime(timezone=True), nullable=False),
        sa.Column('period_end', sa.DateTime(timezone=True), nullable=False),
        sa.Column('subscription_amount', sa.Numeric(10, 2), server_default='0'),
        sa.Column('advertising_amount', sa.Numeric(10, 2), server_default='0'),
        sa.Column('tax_amount', sa.Numeric(10, 2), server_default='0'),
        sa.Column('total_amount', sa.Numeric(10, 2), nullable=False),
        sa.Column('currency', sa.String(3), nullable=False, server_default='BRL'),
        sa.Column('status', sa.String(20), server_default='pending'),
        sa.Column('payment_gateway_ref', sa.String(100)),
        sa.Column('paid_at', sa.DateTime(timezone=True)),
        sa.Column('created_at', sa.DateTime(timezone=True)),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_advertising_invoices_bar_id', 'advertising_invoices', ['bar_id'])
    op.create_index('idx_invoice_bar_status', 'advertising_invoices', ['bar_id', 'status'])
    op.create_index('idx_invoice_period', 'advertising_invoices', ['period_start', 'period_end'])


def downgrade() -> None:
    op.drop_table('advertising_invoices')
    op.drop_table('advertising_impressions')
    op.drop_table('advertising_campaigns')
    op.drop_table('advertising_subscriptions')
    op.drop_table('region_pricing')
