BEGIN;

INSERT INTO core.branches (
    branch_code,
    branch_name,
    city,
    state_code,
    region,
    opened_date
)
VALUES
    ('CA-LA01', 'Los Angeles Central', 'Los Angeles', 'CA', 'West', '2012-01-15'),
    ('CA-LA02', 'Los Angeles South', 'Los Angeles', 'CA', 'West', '2017-06-01'),
    ('CA-SD01', 'San Diego', 'San Diego', 'CA', 'West', '2014-03-10'),
    ('CA-SF01', 'San Francisco', 'San Francisco', 'CA', 'West', '2011-09-05'),
    ('CA-SJ01', 'San Jose', 'San Jose', 'CA', 'West', '2016-04-18'),
    ('CA-SAC1', 'Sacramento', 'Sacramento', 'CA', 'West', '2018-02-12'),
    ('AZ-PHX1', 'Phoenix', 'Phoenix', 'AZ', 'Southwest', '2015-05-20'),
    ('NV-LV01', 'Las Vegas', 'Las Vegas', 'NV', 'West', '2019-01-07'),
    ('TX-DAL1', 'Dallas', 'Dallas', 'TX', 'South', '2010-08-23'),
    ('TX-HOU1', 'Houston', 'Houston', 'TX', 'South', '2011-11-14'),
    ('TX-AUS1', 'Austin', 'Austin', 'TX', 'South', '2018-07-16'),
    ('FL-MIA1', 'Miami', 'Miami', 'FL', 'Southeast', '2013-02-04'),
    ('FL-ORL1', 'Orlando', 'Orlando', 'FL', 'Southeast', '2017-10-09'),
    ('GA-ATL1', 'Atlanta', 'Atlanta', 'GA', 'Southeast', '2012-06-25'),
    ('NC-CLT1', 'Charlotte', 'Charlotte', 'NC', 'Southeast', '2016-08-08'),
    ('NY-NYC1', 'New York Central', 'New York', 'NY', 'Northeast', '2009-04-13'),
    ('NY-BUF1', 'Buffalo', 'Buffalo', 'NY', 'Northeast', '2018-11-05'),
    ('MA-BOS1', 'Boston', 'Boston', 'MA', 'Northeast', '2013-09-30'),
    ('PA-PHL1', 'Philadelphia', 'Philadelphia', 'PA', 'Northeast', '2014-12-01'),
    ('DC-WAS1', 'Washington', 'Washington', 'DC', 'Northeast', '2011-05-09'),
    ('IL-CHI1', 'Chicago Central', 'Chicago', 'IL', 'Midwest', '2010-02-22'),
    ('IL-CHI2', 'Chicago North', 'Chicago', 'IL', 'Midwest', '2019-03-11'),
    ('MI-DET1', 'Detroit', 'Detroit', 'MI', 'Midwest', '2015-07-27'),
    ('OH-COL1', 'Columbus', 'Columbus', 'OH', 'Midwest', '2017-01-23'),
    ('MN-MSP1', 'Minneapolis', 'Minneapolis', 'MN', 'Midwest', '2016-05-02'),
    ('CO-DEN1', 'Denver', 'Denver', 'CO', 'Mountain', '2014-06-16'),
    ('UT-SLC1', 'Salt Lake City', 'Salt Lake City', 'UT', 'Mountain', '2020-02-03'),
    ('WA-SEA1', 'Seattle', 'Seattle', 'WA', 'Northwest', '2012-10-15'),
    ('OR-PDX1', 'Portland', 'Portland', 'OR', 'Northwest', '2016-09-19'),
    ('MO-STL1', 'St. Louis', 'St. Louis', 'MO', 'Midwest', '2018-04-09'),
    ('TN-NSH1', 'Nashville', 'Nashville', 'TN', 'South', '2020-08-17')
ON CONFLICT (branch_code) DO NOTHING;

INSERT INTO core.products (
    product_code,
    product_name,
    product_category,
    base_premium
)
VALUES
    ('AUTO-BASIC', 'Essential Auto', 'Auto', 960.00),
    ('AUTO-PLUS', 'Complete Auto', 'Auto', 1560.00),
    ('HOME-STD', 'Standard Home Protection', 'Home', 1320.00),
    ('HOME-PLUS', 'Premier Home Protection', 'Home', 2160.00),
    ('LIFE-TERM', 'Term Life Protection', 'Life', 540.00),
    ('LIFE-WHOLE', 'Whole Life Protection', 'Life', 1800.00),
    ('HEALTH-IND', 'Individual Health', 'Health', 4200.00),
    ('HEALTH-FAM', 'Family Health', 'Health', 9600.00),
    ('TRAVEL-DOM', 'Domestic Travel', 'Travel', 120.00),
    ('TRAVEL-INT', 'International Travel', 'Travel', 280.00)
ON CONFLICT (product_code) DO NOTHING;

COMMIT;