insert into products (name, price, description, image_url, category, stock)
select *
from (
    values
        (
            'Matte Black Coupe Dinnerware Set',
            129.95,
            'A dramatic matte black dinnerware collection with coupe plates, oval platters, and a matching cup and saucer.',
            'bottom-view-black-oval-rectangular-platters-black-cup-saucer-dark-red-table.jpg',
            'Dinnerware',
            26
        ),
        (
            'Restaurant Stoneware Plate & Bowl Stack',
            149.95,
            'A restaurant-inspired stoneware collection with layered plates and glazed bowls for elevated everyday dining.',
            'kitchen-plates-bowls-counter-restaurant.jpg',
            'Dinnerware',
            32
        ),
        (
            'Floral Enamel Saucepan & Mug Set',
            89.95,
            'A vintage-inspired enamel cookware and mug set with hand-painted floral detailing for a charming kitchen wall display.',
            'pexels-leeloothefirst-5447065.jpg',
            'Cookware',
            18
        ),
        (
            'Emerald Botanical Bowl Set',
            54.95,
            'Glossy green botanical bowls with sculpted leaf texture, ideal for sauces, snacks, sides, and styled serving.',
            'pexels-micheile-10410342.jpg',
            'Serveware',
            36
        ),
        (
            'Blush Stoneware & Brass Flatware Setting',
            169.95,
            'A soft blush table setting paired with warm brass-toned flatware for a polished modern dining table.',
            'top-view-dining-tables-without-food.jpg',
            'Tabletop',
            24
        ),
        (
            'Charcoal Stoneware Place Setting',
            119.95,
            'A charcoal ceramic place setting with layered bowl, plate, cup, and linen accent for a moody tablescape.',
            'top-view-table-arrangement-with-empty-dishes-tableware (1).jpg',
            'Dinnerware',
            28
        ),
        (
            'Graphite Dinnerware & Gold Serve Set',
            139.95,
            'Graphite-toned plates and bowls styled with gold serving pieces for a refined contemporary table.',
            'top-view-table-arrangement-with-empty-dishes-tableware.jpg',
            'Tabletop',
            22
        ),
        (
            'Vintage Silver Flatware & Butter Dish Set',
            74.95,
            'A vintage-style metallic flatware and serveware set with a lidded butter dish for classic entertaining.',
            'view-vintage-metallic-cutlery.jpg',
            'Flatware',
            30
        )
) as new_products(name, price, description, image_url, category, stock)
where not exists (
    select 1
    from products
    where products.image_url = new_products.image_url
       or products.name = new_products.name
);
