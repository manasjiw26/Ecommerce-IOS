insert into products (name, price, description, image_url, category, stock)
select *
from (
    values
        (
            'Heritage Enamel Dutch Oven',
            329.95,
            'A premium enameled Dutch oven for braising, baking, roasting, and slow simmering.',
            'https://images.pexels.com/photos/30981355/pexels-photo-30981355.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Cookware',
            18
        ),
        (
            'Copper Core Saute Pan',
            219.95,
            'A polished saute pan with responsive heat control for sauces, searing, and delicate reductions.',
            'https://images.pexels.com/photos/17542995/pexels-photo-17542995.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Cookware',
            22
        ),
        (
            'Olivewood Prep Board',
            74.95,
            'A richly grained serving and prep board that moves beautifully from counter to table.',
            'https://images.pexels.com/photos/3847514/pexels-photo-3847514.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Accessories',
            36
        ),
        (
            'Professional Knife Block Set',
            299.95,
            'A balanced cutlery set with essential blades for everyday prep and confident entertaining.',
            'https://images.pexels.com/photos/8175345/pexels-photo-8175345.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Cutlery',
            14
        ),
        (
            'Marble Salt & Spice Cellars',
            49.95,
            'Weighted marble cellars for finishing salts, spices, and countertop mise en place.',
            'https://images.pexels.com/photos/8176603/pexels-photo-8176603.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Accessories',
            40
        ),
        (
            'Artisan Stoneware Dinnerware',
            149.95,
            'Layered stoneware place settings with organic edges and a restaurant-quality feel.',
            'https://images.pexels.com/photos/8176590/pexels-photo-8176590.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Dining',
            28
        ),
        (
            'French Press Coffee Set',
            89.95,
            'A glass-and-steel coffee service set designed for rich brews and slow weekend mornings.',
            'https://images.pexels.com/photos/11885824/pexels-photo-11885824.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Appliances',
            24
        ),
        (
            'Brushed Steel Mixing Bowls',
            64.95,
            'Nested stainless steel bowls for baking prep, salad tossing, marinades, and storage.',
            'https://images.pexels.com/photos/15852126/pexels-photo-15852126.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Bakeware',
            32
        ),
        (
            'Linen Table Runner Collection',
            69.95,
            'Washed linen table textiles that bring a soft, tailored finish to everyday dining.',
            'https://images.pexels.com/photos/15569110/pexels-photo-15569110.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Kitchen Linens',
            30
        ),
        (
            'Walnut Utensil Crock Set',
            54.95,
            'Countertop-ready wooden tools and a matching crock for an organized, chef-inspired station.',
            'https://images.pexels.com/photos/3432605/pexels-photo-3432605.jpeg?auto=compress&cs=tinysrgb&w=900',
            'Tools',
            34
        )
) as new_products(name, price, description, image_url, category, stock)
where not exists (
    select 1
    from products
    where products.name = new_products.name
);
